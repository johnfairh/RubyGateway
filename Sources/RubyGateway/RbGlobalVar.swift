//
//  RbObjectGVar.swift
//  RubyGateway
//
//  Distributed under the MIT license, see LICENSE
//

import CRuby
import RubyGatewayHelpers

// Some simple thunking code to wrap up rb_gvar_* code.
//
// We support only 'virtual' gvars which are the most general kind - the 'bound'
// style doesn't work so well with our immutable `RbObject` pattern.

// MARK: Callbacks from C code (rbg_value.m)

private func rbobject_gvar_get_callback(id: ID) -> VALUE {
    return RbGlobalVar.get(id: id)
}

private func rbobject_gvar_set_callback(id: ID,
                                        newValue: VALUE,
                                        returnValue: UnsafeMutablePointer<Rbg_return_value>) {
    RbGlobalVar.set(id: id, newValue: newValue, returnValue: returnValue)
}

private enum RbGlobalVar {

    /// One-time init to register the callbacks
    private static var initOnce: Void = {
        rbg_register_gvar_callbacks(rbobject_gvar_get_callback,
                                    rbobject_gvar_set_callback)
    }()

    /// Callbacks + store
    private struct Context {
        let get: () -> RbObject
        let set: ((RbObject) throws -> Void)?
    }

    private static var contexts: [ID: Context] = [:]

    static func create(name: String,
                       get: @escaping () -> RbObject,
                       set: ((RbObject) throws -> Void)?) {
        let _ = initOnce
        let id = rbg_create_virtual_gvar(name, set == nil ? 1 : 0)
        contexts[id] = Context(get: get, set: set)
    }

    fileprivate static func get(id: ID) -> VALUE {
        if let context = contexts[id] {
            let object = context.get()
            return object.withRubyValue { $0 }
        }
        return Qnil // practically unreachable
    }

    fileprivate static func set(id: ID, newValue: VALUE, returnValue: UnsafeMutablePointer<Rbg_return_value>) {
        if let context = contexts[id],
            let setter = context.set {
            returnValue.setFrom {
                try setter(RbObject(rubyValue: newValue))
                return Qnil
            }
        }
    }
}

// MARK: Swift Global Variables

extension RbGateway {
    /// Create a Ruby global variable implemented by Swift code.
    ///
    /// Errors thrown from the setter closure propagate into Ruby as exceptions.  Ruby does
    /// not permit getters to raise exceptions.
    ///
    /// - parameters:
    ///   - name: The name of the global variable.  Must begin with `$`.  Any existing global
    ///           variable with this name is overwritten.
    ///   - get: Function called whenever Ruby code reads the global variable.
    ///   - set: Function called whenever Ruby code writes the global variable.  This can be `nil`,
    ///          in which case Ruby treats the variable as readonly and raises a suitable
    ///          exception should code attempt to read it.
    /// - throws: `RbError.badIdentifier` if `name` is bad; some other kind of error if Ruby is
    ///           not working.
    public func defineGlobalVar(name: String,
                                get: @escaping () -> RbObject,
                                set: ((RbObject) throws -> Void)? = nil) throws {
        try setup()
        try name.checkRubyGlobalVarName()
        RbGlobalVar.create(name: name, get: get, set: set)
    }
}
