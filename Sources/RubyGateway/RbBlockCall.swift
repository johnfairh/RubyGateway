//
//  RbBlockCall.swift
//  RubyGateway
//
//  Distributed under the MIT license, see LICENSE
//
internal import RubyGatewayHelpers

//
// This file deals with Ruby blocks.  It gets a bit complicated.
//
// There are two slightly different codepaths:
// 1) Call Ruby method passing Swift closure as block
//    * RbBlock.doBlockCall(...blockCall:) creates RbBlockContext
//      object to hold the closure.
//    * Call rb_block_call() with that object which ends up in
//      rbproc_pvoid_block_callback() whenever Ruby deigns to invoke
//      the block.
//    * Retrieve context, run Swift closure, handle exceptions etc.
//    * Pass control back to C code rbg_block_pvoid_callback() /
//      rbg_block_callback_tail().
//
// 2) Call Ruby method passing a Ruby Proc object as a block.
//    * RbBlock.doBlockCall(...block:) uses Proc object as the
//      context, no extra object to worry about here.
//    * Call rb_block_call() with that object which ends up in
//      rbproc_value_block_callback() whenever Ruby deigns to invoke
//      the block.
//    * Retrieve context, invoke Proc, handle exceptions etc.
//    * Pass control back to C code rbg_block_value_callback() /
//      rbg_block_callback_tail().
//    * This is messy because the API function that looks like it
//      should be used instead of this forwarding business,
//      `rb_funcall_with_block`, is `CALL_PUBLIC` instead of
//      `CALL_FCALL` like `rb_funcallv`.  So yuck, we have to do this
//      proxy thing to provide similar level of function.
//

/// The type of a block implemented in Swift.
///
/// The parameter is an array of arguments passed to the block.  If the
/// block has just one argument then this is still an array.
///
/// The interface doesn't support other types of argument, for example keyword or
/// optional.
///
/// Blocks always return a value.  You can use `RbObject.nilObject` if
/// you have nothing useful to return.
///
/// Blocks can throw errors:
/// * Create and throw `RbBreak` instead of Ruby `break`;
/// * Create and throw `RbException` instead of Ruby `raise`;
/// * Throwing any other kind of error (including propagating `RbError`s)
///   causes RubyGateway to convert the error into a Ruby RuntimeError
///   exception and raise it.
///
/// See `RbObjectAccess.call(_:args:kwArgs:blockRetention:blockCall:)` and
/// `RbObject.init(blockCall:)`.
public typealias RbBlockCallback = ([RbObject]) throws -> RbObject

/// Control over how Swift closures passed as blocks are retained.
///
/// When you pass a Swift closure as a block, for example using
/// `RbObjectAccess.call(_:args:kwArgs:blockRetention:blockCall:)`, RubyGateway
/// needs some help to understand how Ruby will use the closure.
///
/// The easiest thing to get wrong is using the default of `.none` when
/// Ruby retains the block for use later.  This causes a hard crash in
/// `RbBlockContext.from(raw:)` when Ruby tries to call the block.
public enum RbBlockRetention {
    /// Do not retain the closure.  The default, appropriate when the block
    /// is used only during execution of the method it is passed to.  For
    /// example `#each`.
    case none

    /// Retain the closure for as long as the object that owns the method.
    /// Use when a method stores a closure in an object property for later use.
    case `self`

    /// Retain the closure for as long as the object returned by the method.
    /// Use when the method is a factory that produces some object and passes
    /// that object the closure.  For example `Proc#new`.
    case returned
}

// MARK: - Swift -> Ruby -> Swift call context

/// Context passed to block callbacks wrapping up a Swift closure.
///
/// This is the object that the retain policy is obsessed about.
private class RbBlockContext {
    let callback: RbBlockCallback

    init(_ callback: @escaping RbBlockCallback) {
        self.callback = callback
    }

    /// Call a function passing it a `void *` representation of the `RbProcContext`
    func withRaw<T>(callback: (UnsafeMutableRawPointer) throws -> T) rethrows -> T {
        let unmanaged = Unmanaged.passRetained(self)
        defer { unmanaged.release() }
        return try callback(unmanaged.toOpaque())
    }

    /// Retrieve an `RbBlockContext` from its `void *` representation
    static func from(raw: UnsafeMutableRawPointer) -> RbBlockContext {
        // A EXC_BAD_ACCESS here usually means the blockRetention has been
        // set wrongly - at any rate, the `RbProcContext` has been deallocated
        // while Ruby was still using it.
        Unmanaged<RbBlockContext>.fromOpaque(raw).takeUnretainedValue()
    }
}

/// The callback from Ruby for blocks implemented by Swift closures.
///
/// VALUE scoping all a bit dodgy here but probably fine in practice...
private func rbproc_pvoid_block_callback(rawContext: UnsafeMutableRawPointer,
                                         argc: Int32, argv: UnsafePointer<VALUE>,
                                         blockArg: VALUE,
                                         returnValue: UnsafeMutablePointer<Rbg_return_value>) {
    returnValue.setFrom {
        let context = RbBlockContext.from(raw: rawContext)
        var args: [RbObject] = []
        for i in 0..<Int(argc) {
            args.append(RbObject(rubyValue: (argv + i).pointee))
        }
        let obj = try context.callback(args)
        return obj.withRubyValue { $0 }
    }
}

/// The callback from Ruby for blocks implemented by Ruby block objects.
///
/// Forward on the call.
private func rbproc_value_block_callback(context: VALUE,
                                         argc: Int32, argv: UnsafePointer<VALUE>,
                                         blockArg: VALUE,
                                         returnValue: UnsafeMutablePointer<Rbg_return_value>) {
    returnValue.setFrom {
        try RbVM.doProtect { tag in
            rbg_proc_call_with_block_protect(context, argc, argv, blockArg, &tag)
        }
    }
}

// MARK: - Utilities for setting up Proc callbacks

/// Enum for namespace
internal enum RbBlock {
    /// One-time init to register the callbacks
    private static let initOnce: Void = {
        rbg_register_pvoid_block_proc_callback(rbproc_pvoid_block_callback)
        rbg_register_value_block_proc_callback(rbproc_value_block_callback)
    }()

    /// Call a method on an object passing a Swift closure as its block
    internal static func doBlockCall(value: VALUE,
                                     methodId: ID,
                                     argValues: [VALUE],
                                     hasKwArgs: Bool,
                                     blockCall: @escaping RbBlockCallback) throws -> (AnyObject, VALUE) {
        let _ = initOnce
        let context = RbBlockContext(blockCall)
        return (context, try context.withRaw { rawContext in
            try RbVM.doProtect { tag in
                rbg_block_call_pvoid_protect(value, methodId,
                                             Int32(argValues.count), argValues,
                                             hasKwArgs ? 1 : 0,
                                             rawContext, &tag)
            }
        })
    }

    /// Call a method on an object passing a Ruby object as its block
    internal static func doBlockCall(value: VALUE,
                                     methodId: ID,
                                     argValues: [VALUE],
                                     hasKwArgs: Bool,
                                     block: VALUE) throws -> VALUE {
        let _ = initOnce
        return try RbVM.doProtect { tag in
            rbg_block_call_value_protect(value, methodId,
                                         Int32(argValues.count), argValues,
                                         hasKwArgs ? 1 : 0,
                                         block, &tag)
        }
    }
}
