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
// For actual class defns will need to `rb_class_of` the self param as well.
// So I guess the Q is whether I can merge that with the globals or have to have
// parallal infra.
//
// Gonna have to revise singleton methods and ruby classes and shit.

public struct RbMethod {

    public var isBlockGiven: Bool {
        return rb_block_given_p() != 0
    }

    public var args: [RbObject] {
        return []
    }
}

/// The function signature for a Ruby method implemented in Swift.
///
/// The `RbObject` is the object the method is being invoked against.
/// The `RbMethod` provides useful services such as argument access.
///
/// You can throw `RbException` to send a Ruby exception back.  Throwing
/// anything else gets wrapped up in an `RbException` and sent back
/// to Ruby.
public typealias RbMethodCallback = (RbObject, RbMethod) throws -> RbObject

// MARK: - Global functions

extension RbGateway {
    /// Define a global function with a fixed number of positional arguments.
    /// The function can also be passed a block.
    ///
    /// - parameter name: The function name.
    /// - parameter args: The number of arguments the function requires, not
    ///                   including any block.
    /// - parameter body: The Swift code to run when the function is called.
    /// - throws: `RbError.badIdentifier(type:id:)` if `name` is bad.
    ///           `RbError.badParameter(_:)` if `args` is silly.
    ///           Some other kind of error if Ruby is not working.
    public func defineGlobalFunction(name: String, args: Int, body: @escaping RbMethodCallback) throws {
        try setup()
        try name.checkRubyMethodName()
        guard args >= 0 && args <= 15 else {
            try RbError.raise(error: RbError.badParameter("args value out of range, \(args)"))
        }
    }
}
