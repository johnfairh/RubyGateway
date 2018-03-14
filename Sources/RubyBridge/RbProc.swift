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


public typealias ProcCallback = ([RbObject]) -> RbObject

fileprivate class RbProcContext {
    enum CallType {
        case callback(ProcCallback)
        case value(VALUE)
    }
    let type: CallType

    init(procCallback: @escaping ProcCallback) {
        type = .callback(procCallback)
    }

    init(procValue: VALUE) {
        type = .value(procValue)
    }

    static func from(raw: UnsafeMutableRawPointer) -> RbProcContext {
        return Unmanaged<RbProcContext>.fromOpaque(raw).takeUnretainedValue()
    }

    func withRaw<T>(callback: (UnsafeMutableRawPointer) throws -> T) rethrows -> T {
        let unmanaged = Unmanaged.passRetained(self)
        defer { unmanaged.release() }
        return try callback(unmanaged.toOpaque())
    }
}

private func rbproc_block_callback(yielded_arg: VALUE,
                                   rawContext: UnsafeMutableRawPointer,
                                   argc: Int32, argv: UnsafePointer<VALUE>,
                                   blockarg: VALUE) -> VALUE {
    let context = RbProcContext.from(raw: rawContext)

    switch context.type {
    case let .callback(procCallback):
        var args: [RbObject] = []
        for i in 0..<Int(argc) {
            args.append(RbObject(rubyValue: (argv + i).pointee))
        }
        let obj = procCallback(args)
        return obj.withRubyValue { $0 }

    case let .value(procValue):
        if let value = try? RbVM.doProtect(call: {
            rbb_proc_call_with_block_protect(procValue, argc, argv, blockarg, nil)
        }) {
            return value
        }
        // TODO!
        return Qnil
    }
}

// -> enum and make the magic happen at `rubyObject` time.
public enum RbProc: RbObjectConvertible {

    case rubyObject(RbObjectConvertible)
    case callback(ProcCallback)

    /// Create from a Ruby object.
    public init(object: RbObjectConvertible) {
        self = .rubyObject(object)
    }

    /// Create from a Swift closure.
    public init(callback: @escaping ProcCallback) {
        self = .callback(callback)
    }

    /// Try to create an `RbProc` from an `RbObject`.
    /// Always succeeds
    /// :nodoc:
    public init?(_ value: RbObject) {
        self.init(object: value)
    }

    /// A Ruby object for the Proc
    public var rubyObject: RbObject {
        guard Ruby.softSetup() else {
            return .nilObject
        }
        switch self {
        case let .callback(callback):
            let context = RbProcContext(procCallback: callback)
            guard let procValue = try? RbProc.makeProc(context: context) else {
                return .nilObject
            }
            let rbObject = RbObject(rubyValue: procValue)
            rbObject.associate(object: context)
            return rbObject

        default:
            fatalError("bang")
        }
    }

    fileprivate static func makeProc(context: RbProcContext) throws -> VALUE {
        return try context.withRaw { rawContext in
            try RbVM.doProtect {
                rbb_proc_new_protect(rbproc_block_callback, rawContext, nil)
            }
        }
    }

    internal static func doBlockCall(value: VALUE, methodId: ID, argValues: [VALUE], procCallback: ProcCallback) throws -> VALUE {
        return try withoutActuallyEscaping(procCallback) { escapable in
            let context = RbProcContext(procCallback: escapable)
            return try context.withRaw { rawContext in
                try RbVM.doProtect {
                    rbb_block_call_protect(value, methodId,
                                           Int32(argValues.count), argValues,
                                           rbproc_block_callback, rawContext,
                                           nil)
                }
            }
        }
    }

    internal static func doBlockCall(value: VALUE, methodId: ID, argValues: [VALUE], procValue: VALUE) throws -> VALUE {
        let context = RbProcContext(procValue: procValue)
        return try context.withRaw { rawContext in
            try RbVM.doProtect {
                rbb_block_call_protect(value, methodId,
                                       Int32(argValues.count), argValues,
                                       rbproc_block_callback, rawContext,
                                       nil)
            }
        }
    }
}
