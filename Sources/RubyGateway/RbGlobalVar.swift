//
//  RbObjectGVar.swift
//  RubyGateway
//
//  Distributed under the MIT license, see LICENSE
//
internal import RubyGatewayHelpers

// Some simple thunking code to wrap up rb_gvar_* code.
//
// We support only 'virtual' gvars which are the most general kind - the 'bound'
// style doesn't work so well with our immutable `RbObject` pattern.

// MARK: Callbacks from C code (rbg_value.m)

private func rbobject_gvar_get_callback(id: ID) -> VALUE {
    RbGlobalVar.get(id: id)
}

private func rbobject_gvar_set_callback(id: ID,
                                        newValue: VALUE,
                                        returnValue: UnsafeMutablePointer<Rbg_return_value>) {
    RbGlobalVar.set(id: id, newValue: newValue, returnValue: returnValue)
}

private enum RbGlobalVar {

    /// One-time init to register the callbacks
    private static let initOnce: Void = {
        rbg_register_gvar_callbacks(rbobject_gvar_get_callback, rbobject_gvar_set_callback)
    }()

    /// Callbacks + store - type-erased at this point
    private struct Context {
        let get: () -> RbObject
        let set: ((RbObject) throws -> Void)?
    }

    private static let contexts = LockedDictionary<ID, Context>()

    /// Create thunks to 
    static func create<T: RbObjectConvertible>(name: String,
                       get: @escaping () -> T,
                       set: ((T) throws -> Void)?) {
        let _ = initOnce
        let id = rbg_create_virtual_gvar(name, set == nil ? 1 : 0)
        let getter = { get().rubyObject }
        if let set = set {
            contexts[id] =
                    Context(get: getter,
                            set: { newRbObject in
                                    guard let typed = T(newRbObject) else {
                                        throw RbException(message: "Bad type of \(newRbObject) expected \(T.self)")
                                    }
                                    try set(typed)
                                }
                            )
        }
        else {
            contexts[id] = Context(get: getter, set: nil)
        }
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
    /// Create a readonly Ruby global variable implemented by Swift code.
    ///
    /// If your global variable is not a simple Swift value type then use `RbObject`
    /// as the closure return type.
    ///
    /// - parameters:
    ///   - name: The name of the global variable.  Must begin with `$`.  Any existing global
    ///           variable with this name is overwritten.
    ///   - get: Function called whenever Ruby code reads the global variable.
    /// - throws: `RbError.badIdentifier(type:id:)` if `name` is bad; some other kind of error if Ruby is
    ///           not working.
    public func defineGlobalVar<T: RbObjectConvertible>(_ name: String,
                                                        get: @escaping @Sendable () -> T) throws {
        try setup()
        try name.checkRubyGlobalVarName()
        RbGlobalVar.create(name: name, get: get, set: nil)
    }

    /// Create a read-write Ruby global variable implemented by Swift code.
    ///
    /// Errors thrown from the setter closure propagate into Ruby as exceptions.  Ruby does
    /// not permit getters to raise exceptions.
    ///
    /// If your global variable is not a simple Swift value type then use `RbObject` as the
    /// closure return/argument type; you can manually throw an `RbException` from the setter
    /// if the provided Ruby value is the wrong shape.
    ///
    /// - parameters:
    ///   - name: The name of the global variable.  Must begin with `$`.  Any existing global
    ///           variable with this name is overwritten.
    ///   - get: Function called whenever Ruby code reads the global variable.
    ///   - set: Function called whenever Ruby code writes the global variable.
    /// - throws: `RbError.badIdentifier(type:id:)` if `name` is bad; some other kind of error if Ruby is
    ///           not working.
    public func defineGlobalVar<T: RbObjectConvertible>(_ name: String,
                                                        get: @escaping @Sendable () -> T,
                                                        set: @escaping @Sendable (T) throws -> Void) throws {
        try setup()
        try name.checkRubyGlobalVarName()
        RbGlobalVar.create(name: name, get: get, set: set)
    }
}
