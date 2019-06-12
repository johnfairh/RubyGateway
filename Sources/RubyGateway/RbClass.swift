//
//  RbClass.swift
//  RubyGateway
//
//  Distributed under the MIT license, see LICENSE
//

import RubyGatewayHelpers
import CRuby

//
// Support for binding Swift objects to Ruby objects.
//
// Usual lack-of-context problem from Ruby, we indirect in a couple of
// places and use the fully qualified Ruby class name as a key in a hash
// on the Swift side to identify the Swift type and initializer.
//
private protocol RbBoundClassProtocol {
    func createInstance() -> UnsafeMutableRawPointer
    func deleteInstance(_ instance: UnsafeMutableRawPointer)
}

private struct RbBoundClass<T: AnyObject> : RbBoundClassProtocol {
    var initializer: () -> T

    func createInstance() -> UnsafeMutableRawPointer {
        let instance = initializer()
        return Unmanaged<T>.passRetained(instance).toOpaque()
    }

    func deleteInstance(_ instance: UnsafeMutableRawPointer) {
        let instance = Unmanaged<T>.fromOpaque(instance)
        instance.release()
    }
}

// Called from rbg_protect.m / rbg_bound_alloc_instance
private func rbbinding_alloc(className: UnsafePointer<Int8>) -> UnsafeMutableRawPointer? {
    let name = String(cString: className)
    return RbClassBinding.alloc(name: name)
}

// Called from rbg_protect.m / rbg_bound_free_data
private func rbbinding_free(className: UnsafePointer<Int8>, instance: UnsafeMutableRawPointer) {
    let name = String(cString: className)
    RbClassBinding.free(name: name, instance: instance)
}

// namespace
internal enum RbClassBinding {

    /// One-time init to register the callbacks
    private static var initOnce: Void = {
        rbg_register_object_binding_callbacks(rbbinding_alloc, rbbinding_free)
    }()

    private static var bindings = [String : RbBoundClassProtocol]()

    fileprivate static func register<T: AnyObject>(name: String, initializer: @escaping () -> T) {
        let _ = initOnce
        bindings[name] = RbBoundClass(initializer: initializer)
    }

    static func alloc(name: String) -> UnsafeMutableRawPointer? {
        guard let binding = bindings[name] else {
            return nil
        }
        return binding.createInstance()
    }

    static func free(name: String, instance: UnsafeMutableRawPointer) {
        if let binding = bindings[name] {
            binding.deleteInstance(instance)
        }
    }
}

// Class and module definitions.
// Really just under RbGateway as a namespace.

// MARK: Defining New Classes and Modules

extension RbGateway {
    /// Define a new, empty, Ruby class.
    ///
    /// - Parameter name: Name of the class.
    /// - Parameter parent: Parent class for the new class to inherit from.  The default
    ///                     is `nil` which means the new class inherits from `Object`.
    /// - Parameter under: The class or module under which to nest this new class.  The
    ///                    default is `nil` which means the class is at the top level.
    /// - Returns: The class object for the new class.
    /// - Throws: `RbError.badIdentifier(type:id:)` if `name` is bad.  `RbError.badType(...)` if
    ///           `parent` is provided but is not a class, or if `under` is neither class nor
    ///           module. `RbError.rubyException(...)` if Ruby is unhappy with the definition,
    ///           for example when the class already exists with a different parent.
    @discardableResult
    public func defineClass(_ name: String, parent: RbObject? = nil, under: RbObject? = nil) throws -> RbObject {
        try setup()
        try name.checkRubyConstantName()
        try parent?.checkIsClass()
        try under?.checkIsClassOrModule()

        let actualParent = parent ?? RbObject(rubyValue: rb_cObject)
        let actualUnder = under ?? .nilObject // Qnil special case in rbg_helpers

        return try actualUnder.withRubyValue { underVal in
            try actualParent.withRubyValue { parentVal in
                try RbVM.doProtect { tag in
                    RbObject(rubyValue: rbg_define_class_protect(name, underVal, parentVal, &tag))
                }
            }
        }
    }

    /// Define a new, empty, Ruby class associated with a Swift class.
    ///
    /// When any new instance of the Ruby class is created, the `initializer` closure
    /// is called to get hold of an instance of the bound Swift class.  Typically this closure
    /// is an initializer for the Swift class.  A strong reference is held to the Swift object
    /// while the Ruby object is live; this reference is released only when the Ruby object is
    /// garbage-collected.
    ///
    /// - Parameter name: Name of the class.
    /// - Parameter under: The class or module under which to nest this new class.  The
    ///                    default is `nil` which means the class is at the top level.
    /// - Parameter initializer: Closure to return an instance of `SwiftPeer`, typically a new
    ///                          instance.
    /// - Returns: The class object for the new class.
    /// - Throws: `RbError.badIdentifier(type:id:)` if `name` is bad.  `RbError.badType(...)` if
    ///           `parent` is provided but is not a class, or if `under` is neither class nor
    ///           module. `RbError.rubyException(...)` if Ruby is unhappy with the definition,
    ///           for example when the class already exists with a different parent.
    @discardableResult
    public func defineClass<SwiftPeer: AnyObject>(_ name: String,
                                                  under: RbObject? = nil,
                                                  initializer: @escaping () -> SwiftPeer) throws -> RbObject {
        try setup()
        let classObj = try defineClass(name, parent: RbObject(rubyValue: rb_cData), under: under)

        RbClassBinding.register(name: String(try classObj.call("name"))!, initializer: initializer)
        classObj.withRubyValue { rbg_bind_class($0) }

        return classObj
    }

    /// Define a new, empty, Ruby module.
    ///
    /// For example to create a module `Math::Advanced`:
    /// ```swift
    /// let mathModule = try Ruby.get("Math")
    /// let advancedMathModule = try Ruby.defineModule(name: "Advanced", under: mathModule)
    /// ```
    ///
    /// - Parameter name: Name of the module.
    /// - Parameter under: The class or module under which to nest this new module.
    /// - Returns: The module object for the new module.
    /// - Throws: `RbError.badIdentifier(type:id:)` if `name` is bad.  `RbError.badType(...)`
    ///           if `under` is neither class nor module.  `RbError.rubyException(...)` if
    ///           Ruby is unhappy with the definition, for example when a non-module constant
    ///           already exists with this name.
    @discardableResult
    public func defineModule(_ name: String, under: RbObject? = nil) throws -> RbObject {
        try setup()
        try name.checkRubyConstantName()
        try under?.checkIsClassOrModule()

        let actualUnder = under ?? .nilObject // Qnil special case in rbg_helpers

        return try actualUnder.withRubyValue { underVal in
            try RbVM.doProtect { tag in
                RbObject(rubyValue: rbg_define_module_protect(name, underVal, &tag))
            }
        }
    }
}

// MARK: Importing Modules

extension RbObject {
    /// Add methods from a module to a class such that methods from the class
    /// override any that match in the module.
    ///
    /// - Parameter module: Module whose methods are to be added.
    /// - Throws: `RbError.badType(...)` if this object is not a class or if `module`
    ///            is not a module.  `RbError.rubyException(...)` if Ruby is unhappy,
    ///            for example if the operation creates a circular dependency.
    public func include(module: RbObject) throws {
        try checkIsClass()
        try module.checkIsModule()
        try doInjectModule(module: module, type: RBG_INJECT_INCLUDE)
    }

    /// Add methods from a module to a class such that methods from the module
    /// override any that match in the class.
    ///
    /// See `Module#prepend` for a better explanation.
    ///
    /// - Parameter module: Module whose methods are to be added.
    /// - Throws: `RbError.badType(...)` if this object is not a class or if `module`
    ///            is not a module.  `RbError.rubyException(...)` if Ruby is unhappy,
    ///            for example if the operation creates a circular dependency.
    public func prepend(module: RbObject) throws {
        try checkIsClass()
        try module.checkIsModule()
        try doInjectModule(module: module, type: RBG_INJECT_PREPEND)
    }

    /// Add methods from a module to the singleton class of this object.
    ///
    /// See `Module#extend` for a better explanation.
    ///
    /// - Parameter module: Module whose methods are to be added.
    /// - Throws: `RbError.badType(...)` if `module` is not a module.
    ///            `RbError.rubyException(...)` if Ruby is unhappy,
    ///            for example if the operation creates a circular dependency.
    public func extend(module: RbObject) throws {
        try module.checkIsModule()
        try doInjectModule(module: module, type: RBG_INJECT_EXTEND)
    }

    /// Helper for include/prepend/extend
    private func doInjectModule(module: RbObject, type: Rbg_inject_type) throws {
        try withRubyValue { myValue in
            try module.withRubyValue { moduleValue in
                try RbVM.doProtect { tag in
                    rbg_inject_module_protect(myValue, moduleValue, type, &tag)
                }
            }
        }
    }
}
