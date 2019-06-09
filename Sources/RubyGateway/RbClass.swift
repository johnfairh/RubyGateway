//
//  RbClass.swift
//  RubyGateway
//
//  Distributed under the MIT license, see LICENSE
//

import RubyGatewayHelpers
import CRuby

// Class and module definitions.
// Really just under RbGateway as a namespace.

// MARK: Defining New Classes and Modules

extension RbGateway {
    /// Define a new, empty, Ruby class.
    ///
    /// - Parameter name: Name of the class.  Can contain `::` sequences to nest the class
    ///                   inside other classes or modules.
    /// - Parameter parent: Parent class for the new class to inherit from.  The default
    ///                     is `nil` which means the new class inherits from `Object`.
    /// - Returns: The class object for the new class.
    /// - Throws: `RbError.badIdentifier(type:id:)` if `name` is bad.  `RbError.badType(...)` if
    ///           `parent` is provided but is not a class.  `RbError.rubyException(...)` if
    ///           Ruby is unhappy with the definition, for example when the class already exists
    ///           with a different parent.
    @discardableResult
    public func defineClass(_ name: String, parent: RbObject? = nil) throws -> RbObject {
        try setup()
        let (parentScope, className) = try decomposePath(name: name)
        return try doDefineClass(name: className, parent: parent, under: parentScope)
    }

    private func decomposePath(name: String) throws -> (RbObject, String) {
        let (parentScope, className) = try name.decomposedConstantPath()

        var scopeClass: RbObject = .nilObject // Qnil special case in rbg_helpers
        if let parentScope = parentScope {
            scopeClass = try get(parentScope)
        }
        return (scopeClass, className)
    }

    /// Define a new, empty, Ruby class nested under an existing class or module.
    ///
    /// - Parameter name: Name of the class.  Cannot contain `::` sequences.
    /// - Parameter parent: Parent class for the new class to inherit from.  The default
    ///                     is `nil` which means the new class inherits from `Object`.
    /// - Parameter under: The class or module under which to nest this new class.
    /// - Returns: The class object for the new class.
    /// - Throws: `RbError.badIdentifier(type:id:)` if `name` is bad.  `RbError.badType(...)` if
    ///           `parent` is provided but is not a class, or if `under` is neither class nor
    ///           module. `RbError.rubyException(...)` if Ruby is unhappy with the definition,
    ///           for example when the class already exists with a different parent.
    @discardableResult
    public func defineClass(_ name: String, parent: RbObject? = nil, under: RbObject) throws -> RbObject {
        try name.checkRubyConstantName()
        try under.checkIsClassOrModule()
        return try doDefineClass(name: name, parent: parent, under: under)
    }

    private func doDefineClass(name: String, parent: RbObject?, under: RbObject) throws -> RbObject {
        let parentClass = parent ?? RbObject(rubyValue: rb_cObject)
        try parentClass.checkIsClass()

        return try under.withRubyValue { underVal in
            try parentClass.withRubyValue { parentVal in
                try RbVM.doProtect { tag in
                    RbObject(rubyValue: rbg_define_class_protect(name, underVal, parentVal, &tag))
                }
            }
        }
    }

    /// Define a new, empty, Ruby module.
    ///
    /// - Parameter name: Name of the module.  Can contain `::` sequences to nest the class
    ///                   under other classes or modules.
    /// - Returns: The module object for the new module.
    /// - Throws: `RbError.badIdentifier(type:id:)` if `name` is bad.  `RbError.rubyException(...)` if
    ///           Ruby is unhappy with the definition, for example when a non-module constant already
    ///           exists with this name.
    @discardableResult
    public func defineModule(_ name: String) throws -> RbObject {
        try setup()
        let (parentScope, modName) = try decomposePath(name: name)
        return try doDefineModule(name: modName, under: parentScope)
    }

    /// Define a new, empty, Ruby module nested under an existing class or module.
    ///
    /// For example to create a module `Math::Advanced`:
    /// ```swift
    /// let mathModule = try Ruby.get("Math")
    /// let advancedMathModule = try Ruby.defineModule(name: "Advanced", under: mathModule)
    /// ```
    ///
    /// - Parameter name: Name of the module.  Cannot contain `::` sequences.
    /// - Parameter under: The class or module under which to nest this new module.
    /// - Returns: The module object for the new module.
    /// - Throws: `RbError.badIdentifier(type:id:)` if `name` is bad.  `RbError.badType(...)`
    ///           if `under` is neither class nor module.  `RbError.rubyException(...)` if
    ///           Ruby is unhappy with the definition, for example when a non-module constant
    ///           already exists with this name.
    @discardableResult
    public func defineModule(_ name: String, under: RbObject) throws -> RbObject {
        try setup()
        try name.checkRubyConstantName()
        try under.checkIsClassOrModule()
        return try doDefineModule(name: name, under: under)
    }

    private func doDefineModule(name: String, under: RbObject) throws -> RbObject {
        return try under.withRubyValue { scopeVal in
            try RbVM.doProtect { tag in
                RbObject(rubyValue: rbg_define_module_protect(name, scopeVal, &tag))
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
