//
//  RbProc.swift
//  RubyBridge
//
//  Distributed under the MIT license, see LICENSE
//

import CRuby
import RubyBridgeHelpers

//
// This file deals with Ruby Procs.  It gets a bit complicated.
//
// Use Case 1 - create Proc object from Swift closure, later on invoke it.
// * Context object `RbProcContext` to hold the Swift callback.
// * `rb_proc_new` stores it.  `Proc#call` calls it.
// * Callback from C level `rbproc_block_callback` to decode context,
//   forward call to Swift closure, forward results back to C layer.
// * Context object survives until the Ruby Proc dies.
//
// Use Case 2 - pass Swift closure as block to Ruby func call.
// * Context object `RbProcContext` to hold the Swift callback.
// * `rb_block_call` calls Ruby func and uses `rbproc_block_callback`
//   as Use Case 1, same as before.
// * Context object is short-lived.
//
// Use Case 3 - pass a Proc object as a block to Ruby func call.
// * Context object `RbProcContext` to hold the Swift callback.
// * `rb_block_call` as per Use Case 2 to call our block callback
//   `rbproc_block_callback`.
// * Then forward to the original proc, `rb_proc_call_with_block`.
// * This is messy because the API function that looks like it
//   should be used, `rb_funcall_with_block`, is `CALL_PUBLIC` instead
//   of `CALL_FCALL` like `rb_funcallv`.  So yuck, we have to do this
//   proxy thing to provide similar level of function.
//

/// The type of a Proc or block implemented in Swift.
///
/// See `RbProc` and `RbObjectAccess.call(_:args:kwArgs:block:blockCall:)`.
public typealias RbProcCallback = ([RbObject]) -> RbObject

// MARK: - Swift -> Ruby -> Swift call context

/// Context passed to block callbacks, wrapping up either a Swift closure
/// or a Ruby Proc to pass on control to.
private class RbProcContext {
    private enum CallType {
        case callback(RbProcCallback)
        case value(VALUE)
    }
    private let type: CallType

    init(procCallback: @escaping RbProcCallback) {
        type = .callback(procCallback)
    }

    init(procValue: VALUE) {
        type = .value(procValue)
    }

    /// Call a function passing it a `void *` representation of the `RbProcContext`
    func withRaw<T>(callback: (UnsafeMutableRawPointer) throws -> T) rethrows -> T {
        let unmanaged = Unmanaged.passRetained(self)
        defer { unmanaged.release() }
        return try callback(unmanaged.toOpaque())
    }

    /// Retrieve an `RbProcContext` from its `void *` representation
    static func from(raw: UnsafeMutableRawPointer) -> RbProcContext {
        return Unmanaged<RbProcContext>.fromOpaque(raw).takeUnretainedValue()
    }

    /// Pass on the proc arguments from Ruby to the wrapped code.
    func invoke(argc: Int32, argv: UnsafePointer<VALUE>, blockArg: VALUE) -> VALUE {
        switch type {
        case let .callback(procCallback):
            // Swift closure - turn everything into RbObjects and call it.
            var args: [RbObject] = []
            for i in 0..<Int(argc) {
                args.append(RbObject(rubyValue: (argv + i).pointee))
            }
            let obj = procCallback(args)
            // TODO: exceptions etc.
            return obj.withRubyValue { $0 }

        case let .value(procValue):
            // Ruby Proc.  Use the API to call it.
            if let value = try? RbVM.doProtect(call: {
                rbb_proc_call_with_block_protect(procValue, argc, argv, blockArg, nil)
            }) {
                return value
            }
            // TODO: handle this
            return Qnil
        }
    }
}

/// The callback from Ruby for all blocks + procs we get involved in.
private func rbproc_block_callback(yielded_arg: VALUE,
                                   rawContext: UnsafeMutableRawPointer,
                                   argc: Int32, argv: UnsafePointer<VALUE>,
                                   blockArg: VALUE) -> VALUE {
    let context = RbProcContext.from(raw: rawContext)
    return context.invoke(argc: argc, argv: argv, blockArg: blockArg)
}

// MARK: - Utilities for setting up Proc callbacks

/// Enum for namespace
internal enum RbProcUtils {

    /// Call a method on an object passing a Swift closure as its block
    internal static func doBlockCall(value: VALUE, methodId: ID, argValues: [VALUE], procCallback: @escaping RbProcCallback) throws -> VALUE {
        let context = RbProcContext(procCallback: procCallback)
        return try doBlockCall(value: value, methodId: methodId, argValues: argValues, procContext: context)
    }

    /// Call a method on an object passing a Proc object as its block
    internal static func doBlockCall(value: VALUE, methodId: ID, argValues: [VALUE], procValue: VALUE) throws -> VALUE {
        let context = RbProcContext(procValue: procValue)
        return try doBlockCall(value: value, methodId: methodId, argValues: argValues, procContext: context)
    }

    /// Call a method on an object passing something as a block.
    private static func doBlockCall(value: VALUE, methodId: ID, argValues: [VALUE], procContext: RbProcContext) throws -> VALUE {
        return try procContext.withRaw { rawContext in
            try RbVM.doProtect {
                rbb_block_call_protect(value, methodId,
                                       Int32(argValues.count), argValues,
                                       rbproc_block_callback, rawContext,
                                       nil)
            }
        }
    }

    /// Create a Proc object from a Swift closure
    fileprivate static func makeProc(procCallback: @escaping RbProcCallback) throws -> RbObject {
        let context = RbProcContext(procCallback: procCallback)
        let procValue = try context.withRaw { rawContext in
            try RbVM.doProtect {
                rbb_proc_new_protect(rbproc_block_callback, rawContext, nil)
            }
        }
        let procObject = RbObject(rubyValue: procValue)
        procObject.associate(object: context)
        return procObject
    }
}

// MARK: - RbProc

/// A Ruby Proc.
///
/// Use this to create a Ruby `Proc` object from either a symbol (or any
/// Ruby object supporting `to_proc`) or a Swift closure.
///
/// The first form is most useful when passing a block to a method:
/// ```swift
/// // Ruby: mapped = names.map(&:downcase)
/// let mapped = names.call("map", block: RbProc(RbSymbol("downcase")))
/// ```
///
/// The second form is for when you need to pass an explicit `Proc`
/// implemented in Swift:
/// ```swift
/// let myProc = RbProc() { args in
///     args.forEach { doSomething(String($0)) }
///     return .nilObject
/// }
///
/// myRubyObj.set("responseProc", args: [myProc])
/// ```
///
/// If you want to pass Swift code to a method as a block then just call
/// `RbObjectAccess.call(_:args:kwArgs:blockCall:)` directly, no need for
/// an `RbProc`.
public enum RbProc: RbObjectConvertible {

    /// A proc implemented via a Ruby value :nodoc:
    case rubyObject(RbObjectConvertible)
    /// A proc implemented by a Swift closure :nodoc:
    case callback(RbProcCallback)

    /// Create from a Ruby object.
    public init(object: RbObjectConvertible) {
        self = .rubyObject(object)
    }

    /// Create from a Swift closure.
    public init(callback: @escaping RbProcCallback) {
        self = .callback(callback)
    }

    /// Try to create an `RbProc` from an `RbObject`.
    /// Succeeds if the object can be used as a Proc (has `to_proc`).
    public init?(_ value: RbObject) {
        guard (try? value.call("respond_to", args: ["to_proc"])) != nil else {
            return nil
        }
        self.init(object: value)
    }

    /// A Ruby object for the Proc
    ///
    /// - warning: You must be sure that Ruby code does not use this Proc after
    ///   the returned `RbObject` has been deallocated.  This normally happens naturally
    ///   but if you are wrapping a Swift closure to pass to a Ruby service that retains
    ///   the Proc for later use, watch out.  Part of the mechanics of invoking the Swift
    ///   closure is tied to the `RbObject` and the program is likely to crash or worse
    ///   if it has been deallocated when the Proc is called.
    public var rubyObject: RbObject {
        guard Ruby.softSetup() else {
            return .nilObject
        }
        switch self {
        case let .callback(callback):
            return (try? RbProcUtils.makeProc(procCallback: callback)) ?? .nilObject

        case let .rubyObject(convertible):
            // TODO: get object, to_proc it
            fatalError("bang: \(convertible)")
        }
    }
}

// MARK: - CustomStringConvertible

extension RbProc: CustomStringConvertible {
    /// A textual representation of the `RbProc`
    public var description: String {
        switch self {
        case .callback:
            return "RbProc(swift closure)"
        case .rubyObject:
            return "RbProc(ruby object)"
        }
    }
}
