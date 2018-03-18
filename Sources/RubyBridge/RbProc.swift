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
/// The parameter is an array of arguments passed to the proc.  If the
/// proc has just one argument then this is still an array.
///
/// Procs always return a value.  You can use `RbObject.nilObject` if
/// you have nothing useful to return.
///
/// Procs can throw errors:
/// * Create and throw `RbBreak` instead of Ruby `break`;
/// * Create and throw `RbException` instead of Ruby `raise`;
/// * Throwing any other kind of error (including propagating `RbError`s)
///   causes RubyBridge to convert the error into a Ruby RuntimeError
///   exception and raise it.
///
/// See `RbProc` and `RbObjectAccess.call(_:args:kwArgs:blockCall:)`.
public typealias RbProcCallback = ([RbObject]) throws -> RbObject

// MARK: - Swift -> Ruby -> Swift call context

/// Some code to be run
enum RbProcCallType {
    case callback(RbProcCallback)
    case value(VALUE)
}

/// Context passed to block callbacks, wrapping up either a Swift closure
/// or a Ruby Proc to pass on control to.
private class RbProcContext {
    private let type: RbProcCallType

    init(_ type: RbProcCallType) {
        self.type = type
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
    func invoke(argc: Int32, argv: UnsafePointer<VALUE>, blockArg: VALUE) throws -> VALUE {
        switch type {
        case let .callback(procCallback):
            // Swift closure - turn everything into RbObjects and call it.
            var args: [RbObject] = []
            for i in 0..<Int(argc) {
                args.append(RbObject(rubyValue: (argv + i).pointee))
            }
            let obj = try procCallback(args)
            return obj.withRubyValue { $0 }

        case let .value(procValue):
            // Ruby Proc.  Use the API to call it.
            return try RbVM.doProtect {
                rbb_proc_call_with_block_protect(procValue, argc, argv, blockArg, nil)
            }
        }
    }
}

extension UnsafeMutablePointer where Pointee == Rbb_return_value {
    func set(type: Rbb_return_type, value: VALUE) {
        pointee.type = type
        pointee.value = value
    }
}

/// The callback from Ruby for all blocks + procs we get involved in.
/// VALUE scoping all a bit dodgy here but probably fine in practice...
private func rbproc_block_callback(rawContext: UnsafeMutableRawPointer,
                                   argc: Int32, argv: UnsafePointer<VALUE>,
                                   blockArg: VALUE,
                                   returnValue: UnsafeMutablePointer<Rbb_return_value>) {
    let context = RbProcContext.from(raw: rawContext)
    do {
        let retVal = try context.invoke(argc: argc, argv: argv, blockArg: blockArg)
        returnValue.set(type: RBB_RT_VALUE, value: retVal)
    } catch RbError.rubyException(let exn) {
        // RubyBridge/Ruby code threw exception
        returnValue.set(type: RBB_RT_RAISE, value: exn.exception.withRubyValue { $0 })
    } catch let exn as RbException {
        // User Swift code generated Ruby exception
        returnValue.set(type: RBB_RT_RAISE, value: exn.exception.withRubyValue { $0 })
    } catch let brk as RbBreak {
        // 'break' from iterator
        if let brkObject = brk.object {
            returnValue.set(type: RBB_RT_BREAK_VALUE, value: brkObject.withRubyValue{ $0 })
        } else {
            returnValue.set(type: RBB_RT_BREAK, value: Qundef)
        }
    } catch {
        // User Swift code or RubyBridge threw Swift error.  Oh for typed throws.
        // Wrap it up in a Ruby exception and raise that instead!
        let rbExn = RbException(message: "Unexpected Swift error thrown: \(error)")
        returnValue.set(type: RBB_RT_RAISE, value: rbExn.exception.withRubyValue { $0 })
    }
}

// MARK: - Utilities for setting up Proc callbacks

/// Enum for namespace
internal enum RbProcUtils {

    /// One-time init to register the callback
    private static var initOnce: Void = {
        rbb_register_block_proc_callback(rbproc_block_callback)
    }()

    /// Call a method on an object passing something as its block
    internal static func doBlockCall(value: VALUE,
                                     methodId: ID,
                                     argValues: [VALUE],
                                     block: RbProcCallType) throws -> (AnyObject, VALUE) {
        let _ = initOnce
        let context = RbProcContext(block)
        return (context, try context.withRaw { rawContext in
            try RbVM.doProtect {
                rbb_block_call_protect(value, methodId,
                                       Int32(argValues.count), argValues,
                                       rawContext, nil)
            }
        })
    }

    /// Create a Proc object from a Swift closure
    fileprivate static func makeProc(procCallback: @escaping RbProcCallback) throws -> RbObject {
        let _ = initOnce
        let context = RbProcContext(.callback(procCallback))
        let procValue = try context.withRaw { rawContext in
            try RbVM.doProtect {
                rbb_proc_new_protect(rawContext, nil)
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
///
/// - warning: When you create an `RbProc` from a Swift callback using
///   `RbProc.init(callback:)` and pass this as a Proc to Ruby, you must be sure
///   that Ruby code does not invoke the Proc after the `RbObject` has been
///   deallocated.  This normally happens naturally, but if you are wrapping a
///   Swift closure to pass to a Ruby service that retains the Proc for later
///   use, then watch out.  Parts of the mechanics of invoking the Swift closure
///   are tied to the `RbObject` and the program is likely to crash or worse if
///   it has been deallocated when the Proc is called.
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
        guard let obj = try? value.call("respond_to?", args: ["to_proc"]),
            obj.isTruthy else {
            return nil
        }
        self.init(object: value)
    }

    /// A Ruby object for the Proc
    ///
    /// - warning: You must be sure that Ruby code does not use this Proc after
    ///   the returned `RbObject` has been deallocated.  This normally happens naturally
    ///   but if you are wrapping a Swift closure to pass to a Ruby service that retains
    ///   the Proc for later use, then watch out.  Parts of the mechanics of invoking the
    ///   Swift closure are tied to the `RbObject` and the program is likely to crash or
    ///   worse if it has been deallocated when the Proc is called.
    public var rubyObject: RbObject {
        guard Ruby.softSetup() else {
            return .nilObject
        }
        switch self {
        case let .callback(callback):
            return (try? RbProcUtils.makeProc(procCallback: callback)) ?? .nilObject

        case let .rubyObject(convertible):
            let obj = convertible.rubyObject
            return (try? obj.call("to_proc")) ?? .nilObject
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
