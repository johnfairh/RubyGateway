//
//  RbMethod.swift
//  RubyGateway
//
//  Distributed under the MIT license, see LICENSE
//

import CRuby
import RubyGatewayHelpers

// Stuff to deal with implementing Ruby methods in Swift and handling calls
// from Ruby into Swift.
//
// Real struggle is how to model the full flexibility of Ruby invocation.
// Answer has to be to provide scan_args wrappers - template at call time not
// defn time for flexibility.
//
// Will use 'simple' fixed-arity functions as a bringup, we need them I suppose
// to do arity-policing.
//
// The Swift function signatures feel different so will not try to wrap up both
// styles of function in an enum. Tbd.
//
// super
// yield
// block-given
// need-block
// (scan_args)
// These all work off of static thread context, ie. are free functions in the API.
// For discoverability though I'm considering putting them in some kind of 'services'
// object passed in the methods.
//
// that would unify the closure type by pushing the fixed args in too.
//
// the *real* real struggle of course is figuring out how to pass context around.  I
// think we're going to have use the method name (symbol/whatevs) as a key and query
// it at invocation time from the C shim to figure out where to go.
//
// We need two separate callbacks, one for normal methods (keyed by class-of-object)
// and one for static methods / singleton object methods (keyed by object).
//
// Ok.  Flaw: I forgot about dynamic dispatch.
// So, if we define a method m in class A, and class B: A, and object b: B then
// calling b.m causes self.class == B and m will not resolve.
//
// Could insist on unique method names but, well.
//
// Ruby does make `ancestors` available to give class and hierarchy, importantly in
// dispatch order.  So we can search ancestors looking for a match.  Will normally
// hit in first position; if later up then can cache that for subsequent calls.
// OK - not THAT bad!
//
// For regular methods need to do self.class.ancestors; for metatypes self.ancestors
// for class methods - for metatype object methods not sure yet.

/// The function signature for a Ruby method implemented in Swift.
///
/// The `RbObject` is the object the method is being invoked against.
/// The `RbMethod` provides useful services such as argument access.
///
/// You can throw `RbException` to send a Ruby exception back.  Throwing
/// anything else gets wrapped up in an `RbException` and sent back
/// to Ruby.
public typealias RbMethodCallback = (RbObject, RbMethod) throws -> RbObject

// MARK: - Dispatch gorpy implementation

/// Callback from the C layer eg `rbg_method_varargs_callback` in `rbg_protect.m`.
/// Swiften the arrays and wrap up the Ruby exception layer.
private func rbmethod_callback(symbol: VALUE,
                               targetCount: Int,
                               rawTargets: UnsafePointer<VALUE>,
                               rubySelf: VALUE,
                               argc: Int32,
                               argv: UnsafePointer<VALUE>,
                               returnValue: UnsafeMutablePointer<Rbg_return_value>) {

    let targets = Array(UnsafeBufferPointer(start: rawTargets, count: targetCount))
    let args    = Array(UnsafeBufferPointer(start: argv, count: Int(argc)))
    return returnValue.setFrom {
        try RbMethodDispatch.exec(symbol: symbol, targets: targets,
                                  rbSelf: RbObject(rubyValue: rubySelf),
                                  argv: args.map(RbObject.init(rubyValue:)))
    }
}

/// `Rbg_method_id` is a C struct used to unique method callbacks.
/// We can't have one callback per method because longjmp, so have to
/// decode what is meant by reverse engineering the method dispatch.
/// :nodoc:
extension Rbg_method_id: Hashable {
    public static func == (lhs: Rbg_method_id, rhs: Rbg_method_id) -> Bool {
        return (lhs.method == rhs.method) &&
               (lhs.target == rhs.target)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(method)
        hasher.combine(target)
    }
}

/// The context required to issue a callback.
private struct RbMethodExec {
    /// Number of arguments required for the method, or `nil` if variable/complicated.
    /// Like Ruby, does not refer to the block in any way.  Don't count the block here.
    var argc: Int?

    /// The Swift implementation of the method.
    var callback: RbMethodCallback

    func exec(rbSelf: RbObject, argv: [RbObject]) throws -> RbObject {
        // Police argc if appropriate
        if let argc = argc {
            if argv.count != argc {
                throw RbException(message: "Wrong number of arguments, given \(argv.count) expected \(argc)")
            }
        }
        return try callback(rbSelf, RbMethod(argv: argv))
    }
}

private struct RbMethodDispatch {
    /// One-time init to register the callbacks
    private static var initOnce: Void = {
        rbg_register_method_callback(rbmethod_callback)
    }()

    /// List of all method callbacks
    private static var callbacks: [Rbg_method_id : RbMethodExec] = [:]

    /// Try to find a callback matching the class/method-name pair.
    static func findCallback(symbol: VALUE, target: VALUE, firstTarget: VALUE) -> RbMethodExec? {
        let mid = Rbg_method_id(method: symbol, target: target)
        guard let callback = callbacks[mid] else {
            return nil
        }
        // Spot case where we define a method and get called from a subclass instance.
        // Remember what happened so we don't have to walk the hierarchy next time.
        if target != firstTarget {
            let firstMid = Rbg_method_id(method: symbol, target: firstTarget)
            callbacks[firstMid] = callback
        }
        return callback
    }

    static func exec(symbol: VALUE, targets: [VALUE], rbSelf: RbObject, argv: [RbObject]) throws -> VALUE {
        let firstTarget = targets.first!
        for target in targets {
            guard let callback = findCallback(symbol: symbol, target: target, firstTarget: firstTarget) else {
                continue
            }
            return try callback.exec(rbSelf: rbSelf, argv: argv).withRubyValue { $0 }
        }
        throw RbException(message: "Can't match method ID to Swift callback")
    }

    // APIs

    static func defineGlobalFunction(name: String, argc: Int?, body: @escaping RbMethodCallback) {
        let _ = initOnce
        let mid = rbg_define_global_function(name)
        callbacks[mid] = RbMethodExec(argc: argc, callback: body)
    }
}

// MARK: - RbMethod

/// Structure passed in to Swift implementations of Ruby functions offering useful services.
public struct RbMethod {

    /// The raw Ruby objects passed as args to the function.
    public let argv: [RbObject]

    init(argv: [RbObject]) {
        self.argv = argv
    }

//    public var isBlockGiven: Bool {
//        return rb_block_given_p() != 0
//    }
}

// MARK: - Global functions

extension RbGateway {
    /// Define a global function that can use positional, keyword, and optional
    /// arguments as well as splatting.  The function can also be passed a block.
    ///
    /// Use the `RbMethod` passed into `body` to access the function arguments.
    /// You have to implement all argument checking rules yourself.
    ///
    /// - parameter name: The function name.
    /// - parameter body: The Swift code to run when the function is called.
    /// - throws: `RbError.badIdentifier(type:id:)` if `name` is bad.
    ///           `RbError.badParameter(_:)` if `args` is silly.
    ///           Some other kind of error if Ruby is not working.
    public func defineGlobalFunction(name: String, body: @escaping RbMethodCallback) throws {
        try doDefineGlobalFunction(name: name, argc: nil, body: body)
    }

    /// Define a global function with a fixed number of positional arguments.
    /// The function can also be passed a block.
    ///
    /// RubyGateway guarantees that the `body` callback is invoked with the
    /// required number of parameters.
    ///
    /// To use other argument styles, use `defineGlobalFunction(name:body:)`.
    ///
    /// - parameter name: The function name.
    /// - parameter argc: The number of arguments the function requires, not
    ///                   including any block.
    /// - parameter body: The Swift code to run when the function is called.
    /// - throws: `RbError.badIdentifier(type:id:)` if `name` is bad.
    ///           `RbError.badParameter(_:)` if `args` is silly.
    ///           Some other kind of error if Ruby is not working.
    public func defineGlobalFunction(name: String, argc: Int, body: @escaping RbMethodCallback) throws {
        try doDefineGlobalFunction(name: name, argc: argc, body: body)
    }

    private func doDefineGlobalFunction(name: String, argc: Int?, body: @escaping RbMethodCallback) throws {
        try setup()
        try name.checkRubyMethodName()
        if let argc = argc {
            guard argc >= 0 && argc <= 9 else {
                try RbError.raise(error: RbError.badParameter("argc value out of range, \(argc)"))
            }
        }
        RbMethodDispatch.defineGlobalFunction(name: name, argc: argc, body: body)
    }
}
