//
//  RbObjectAccess.swift
//  RubyBridge
//
//  Distributed under the MIT license, see LICENSE
//

import CRuby
import RubyBridgeHelpers

/// Provides services to manipulate a Ruby object:
/// * Call methods;
/// * Access properties and instance variables;
/// * Access class variables;
/// * Access global variables;
/// * Find constants, classes, and modules.
///
/// The class is abstract.  You use it via `RbObject` and the global `Ruby` instance
/// of `RbBridge`.
///
/// By default all methods throw `RbError`s if anything goes wrong including
/// when Ruby raises an exception.  Use the `RbObjectAccess.failable` adapter to
/// access an alternative API that returns `nil` on errors instead.  You can still
/// see any Ruby exceptions via `RbError.history`.
public class RbObjectAccess {
    /// Getter for the `VALUE` associated with this object
    private let getValue: () -> VALUE

    /// Set up Swift access to a Ruby object.
    /// - parameter getValue: Getter for the `VALUE` to be accessed.
    init(getValue: @escaping () -> VALUE) {
        self.getValue = getValue
    }

    // MARK: - Instance Variables

    // These guys need to be overridden for top self + can't do if in extension....

    /// Get the value of a Ruby instance variable.  Creates a new one with a `nil` value
    /// if it doesn't exist yet.
    ///
    /// For a version that does not throw, see `failable`.
    ///
    /// - parameter name: Name of IVar to get.  Must begin with a single '@'.
    /// - returns: Value of the IVar or Ruby `nil` if it has not been assigned yet.
    /// - throws: `RbError.badIdentifier` if `name` looks wrong.
    ///           `RbError.rubyException` if Ruby has a problem.
    public func getInstanceVar(_ name: String) throws -> RbObject {
        try Ruby.setup()
        try name.checkRubyInstanceVarName()
        let id = try Ruby.getID(for: name)

        return RbObject(rubyValue: rb_ivar_get(getValue(), id))
    }

    /// Set a Ruby instance variable.  Creates a new one if it doesn't exist yet.
    ///
    /// For a version that does not throw, see `failable`.
    ///
    /// - parameter name: Name of Ivar to set.  Must begin with a single '@'.
    /// - parameter newValue: New value to set.
    /// - returns: The value that was set.
    /// - throws: `RbError.badIdentifier` if `name` looks wrong.
    ///           `RbError.rubyException` if Ruby has a problem.
    @discardableResult
    public func setInstanceVar(_ name: String, newValue: RbObjectConvertible) throws -> RbObject {
        try Ruby.setup()
        try name.checkRubyInstanceVarName()
        let id = try Ruby.getID(for: name)

        return RbObject(rubyValue: newValue.rubyObject.withRubyValue { newRubyValue in
            return rb_ivar_set(getValue(), id, newRubyValue)
        })
    }
}

// MARK: - Constants

extension RbObjectAccess {
    /// Get an `RbObject` that represents a Ruby constant.
    ///
    /// In Ruby constants include things that users think of as constants like
    /// `Math::PI`, classes, and modules.  You can use this routine with
    /// any kind of constant, but see `getClass(...)` for a little more sugar.
    ///
    /// ```swift
    /// let rubyPi = Ruby.getConstant("Math::PI")
    /// let crumbs = rubyPi - Double.pi
    /// ```
    /// This is a dynamic call into Ruby that can cause calls to `const_missing`
    /// and autoloading.
    ///
    /// For a version that does not throw, see `failable`.
    ///
    /// - parameter name: The name of the constant to look up.  Can contain '::' sequences
    ///   to drill down through nested classes and modules.
    ///
    ///   If you call this method on an `RbObject` then `name` is resolved like Ruby does,
    ///   looking up the inheritance chain if there is no local match.
    /// - returns: An `RbObject` for the constant.
    /// - throws: `RbError.rubyException` if the constant cannot be found.
    public func getConstant(_ name: String) throws -> RbObject {
        try Ruby.setup()
        try name.checkRubyConstantName()

        var nextValue = getValue()

        try name.components(separatedBy: "::").forEach { name in
            let rbId = try Ruby.getID(for: name)
            if nextValue == getValue() {
                // For the first item in the path, allow a hit here or above in the hierarchy
                nextValue = try RbVM.doProtect {
                    rbb_const_get_protect(nextValue, rbId, nil)
                }
            } else {
                // Once found a place to start, insist on stepping down from there.
                nextValue = try RbVM.doProtect {
                    rbb_const_get_at_protect(nextValue, rbId, nil)
                }
            }
        }
        return RbObject(rubyValue: nextValue)
    }

    /// Get an `RbObject` that represents a Ruby class.
    ///
    /// This is a dynamic call into Ruby that can cause calls to `const_missing`
    /// and autoloading.
    ///
    /// One way of creating an instance of a class:
    /// ```swift
    /// let myClass = try Ruby.getClass("MyModule::MyClass")
    /// let myObj = try myClass.call("new")
    /// ```
    ///
    /// Although it is easier to write:
    /// ```swift
    /// let myObj = try RbObject(ofClass: "MyModule::MyClass")
    /// ```
    ///
    /// For a version that does not throw, see `failable`.
    ///
    /// - parameter name: The name of the class to look up.  Can contain '::' sequences
    ///   to drill down through nested classes and modules.
    ///
    ///   If you call this method on an `RbObject` then `name` is resolved like Ruby does,
    ///   looking up the inheritance chain if there is no match.
    /// - returns: An `RbObject` for the class.
    /// - throws: `RbError.rubyException` if the constant cannot be found.
    ///           `RbError.badType` if the constant is found but is not a class.
    public func getClass(_ name: String) throws -> RbObject {
        let obj = try getConstant(name)
        guard obj.rubyType == .T_CLASS else {
            try RbError.raise(error: .badType("Found constant called \(name) but it is not a class."))
        }
        return obj
    }
}

// MARK: - Method Call

extension RbObjectAccess {
    /// Call a Ruby object method.
    ///
    /// - parameter methodName: The name of the method to call.
    /// - parameter args: The positional arguments to the method.  None by default.
    /// - parameter kwArgs: The keyword arguments to the method.  None by default.
    /// - returns: The result of calling the method.
    /// - throws: `RbError.rubyException` if there is a Ruby exception.
    ///           `RbError.duplicateKwArg` if there are duplicate keywords in `kwArgs`.
    ///
    /// For a version that does not throw, see `failable`.
    ///
    /// TODO: blocks.
    @discardableResult
    public func call(_ methodName: String,
                     args: [RbObjectConvertible] = [],
                     kwArgs: [(String, RbObjectConvertible)] = []) throws -> RbObject {
        try Ruby.setup()
        let methodId = try Ruby.getID(for: methodName)
        return try doCall(id: methodId, args: args, kwArgs: kwArgs)
    }

    /// Call a Ruby object method using a symbol.
    ///
    /// - parameter symbol: The symbol for the name of the method to call.
    /// - parameter args: The positional arguments to the method.  None by default.
    /// - parameter kwArgs: The keyword arguments to the method.  None by default.
    /// - returns: The result of calling the method.
    /// - throws: `RbError.rubyException` if there is a Ruby exception.
    ///           `RbError.badType` if `symbol` is not a symbol.
    ///           `RbError.duplicateKwArg` if there are duplicate keywords in `kwArgs`.
    ///
    /// For a version that does not throw, see `failable`.
    ///
    /// TODO: blocks.
    @discardableResult
    public func call(symbol: RbObjectConvertible,
                     args: [RbObjectConvertible] = [],
                     kwArgs: [(String, RbObjectConvertible)] = []) throws -> RbObject {
        try Ruby.setup()
        let symbolObj = symbol.rubyObject
        guard symbolObj.rubyType == .T_SYMBOL else {
            throw RbError.badType("Expected T_SYMBOL, got \(symbolObj.rubyType.rawValue) \(symbol)")
        }
        return try symbolObj.withRubyValue { symValue in
            try doCall(id: rb_sym2id(symValue), args: args, kwArgs: kwArgs)
        }
    }

    /// Backend to method-call / message-send.
    private func doCall(id: ID,
                        args: [RbObjectConvertible],
                        kwArgs: [(String, RbObjectConvertible)]) throws -> RbObject {
        var argObjects = args.map { $0.rubyObject }

        if kwArgs.count > 0 {
            try argObjects.append(buildKwArgsHash(from: kwArgs))
        }

        let resultVal = try argObjects.withRubyValues { argValues in
            try RbVM.doProtect {
                rbb_funcallv_protect(getValue(), id, Int32(argValues.count), argValues, nil)
            }
        }

        return RbObject(rubyValue: resultVal)
    }

    /// Start sketching version of call accepting Swift code as block.
    @discardableResult
    public func call(_ methodName: String,
                     args: [RbObjectConvertible] = [],
                     kwArgs: [(String, RbObjectConvertible)] = [],
                     block: ([RbObject]) -> RbObject) throws -> RbObject {
        try Ruby.setup()
        let methodId = try Ruby.getID(for: methodName)
        var argObjects = args.map { $0.rubyObject }

        if kwArgs.count > 0 {
            try argObjects.append(buildKwArgsHash(from: kwArgs))
        }

        let resultVal = try argObjects.withRubyValues {
            try RbProc.doBlockCall(value: getValue(), methodId: methodId,
                                   argValues: $0, procCallback: block)
        }

        return RbObject(rubyValue: resultVal)
    }

    /// Start sketching version of call accepting Ruby proc as block.
    @discardableResult
    public func call(_ methodName: String,
                     args: [RbObjectConvertible] = [],
                     kwArgs: [(String, RbObjectConvertible)] = [],
                     block: RbObjectConvertible) throws -> RbObject {
        try Ruby.setup()
        let methodId = try Ruby.getID(for: methodName)
        var argObjects = args.map { $0.rubyObject }

        if kwArgs.count > 0 {
            try argObjects.append(buildKwArgsHash(from: kwArgs))
        }

        let resultVal = try block.rubyObject.withRubyValue { procValue in
            try argObjects.withRubyValues {
                try RbProc.doBlockCall(value: getValue(), methodId: methodId,
                                       argValues: $0, procValue: procValue)
            }
        }

        return RbObject(rubyValue: resultVal)
    }


    /// Build a keyword args hash.  The keys are Symbols of the keywords.
    private func buildKwArgsHash(from kwArgs: [(String, RbObjectConvertible)]) throws -> RbObject {
        let hashValue = rb_hash_new()
        try kwArgs.forEach { (key, value) in
            try RbSymbol(key).rubyObject.withRubyValue { symValue in
                if rb_hash_lookup(hashValue, symValue) != Qnil {
                    try RbError.raise(error: .duplicateKwArg(key))
                }
                value.rubyObject.withRubyValue {
                    rb_hash_aset(hashValue, symValue, $0)
                }
            }
        }
        return RbObject(rubyValue: hashValue)
    }

    /// Get an attribute of a Ruby object.
    ///
    /// Attributes are declared with `:attr_accessor` and so on -- this routine is a
    /// simple wrapper around `call(...)` for symmetry with `set(...)`.
    ///
    /// For a version that does not throw, see `failable`.
    ///
    /// - parameter name: The name of the attribute to get.
    /// - returns: The value of the attribute.
    /// - throws: `RbError.badIdentifier` if `name` looks wrong.
    ///           `RbError.rubyException` if Ruby has a problem, probably means
    ///           `attribute` doesn't exist.
    public func getAttribute(_ name: String) throws -> RbObject {
        try name.checkRubyMethodName()
        return try call(name)
    }

    /// Set an attribute of a Ruby object.
    ///
    /// Attributes are declared with `:attr_accessor` and so on -- this routine is a
    /// wrapper around a call to the `attrname=` method.
    ///
    /// For a version that does not throw, see `failable`.
    ///
    /// - parameter name: The name of the attribute to set.
    /// - parameter value: The new value of the attribute.
    /// - returns: Whatever the attribute setter returns, typically the new value.
    /// - throws: `RbError.badIdentifier` if `name` looks wrong.
    ///           `RbError.rubyException` if Ruby has a problem, probably means
    ///           `attribute` doesn't exist.
    @discardableResult
    public func setAttribute(_ name: String, newValue: RbObjectConvertible) throws -> RbObject {
        try name.checkRubyMethodName()
        return try call("\(name)=", args: [newValue])
    }
}

// MARK: - Class Variables

extension RbObjectAccess {
    /// Check the associated rubyValue is for a class.
    private func checkClass() throws {
        guard TYPE(getValue()) == .T_CLASS else {
            try RbError.raise(error: .badType("\(getValue()) is not a class, cannot get/setClassVar() on it."))
        }
    }

    /// Get the value of a Ruby class variable that has already been written.
    ///
    /// Must be called on an `RbObject` for a class, or `RbBridge`.  **Note** this
    /// is different from Ruby as-written where you write `@@fred` in an object
    /// context to get a CVar on the object's class.
    ///
    /// The behavior of accessing a non-existent CVar is not consistent with IVars
    /// or GVars.  This is how Ruby works; one more reason to avoid CVars.
    ///
    /// For a version that does not throw, see `failable`.
    ///
    /// - parameter name: Name of CVar to get.  Must begin with '@@'.
    /// - returns: The value of the CVar.
    /// - throws: `RbError.badIdentifier` if `name` looks wrong.
    ///           `RbError.badType` if the object is not a class.
    ///           `RbError.rubyException` if Ruby has a problem -- in particular,
    ///           if the CVar does not exist.
    public func getClassVar(_ name: String) throws -> RbObject {
        try Ruby.setup()
        try name.checkRubyClassVarName()
        try checkClass()

        let id = try Ruby.getID(for: name)

        return try RbObject(rubyValue: RbVM.doProtect {
            rbb_cvar_get_protect(getValue(), id, nil)
        })
    }

    /// Set a Ruby class variable.  Creates a new one if it doesn't exist yet.
    ///
    /// Must be called on an `RbObject` for a class, or `RbBridge`.  **Note** this
    /// is different from Ruby as-written where you write `@@fred = thing` in an
    /// object context to set a CVar on the object's class.
    ///
    /// For a version that does not throw, see `failable`.
    ///
    /// - parameter name: Name of the CVar to set.  Must begin with '@@'.
    /// - parameter newValue: The new value to set.
    /// - returns: The value that was set.
    /// - throws: `RbError.badIdentifier` if `name` looks wrong.
    ///           `RbError.badType` if the object is not a class.
    ///           `RbError.rubyException` if Ruby has a problem.
    @discardableResult
    public func setClassVar(_ name: String, newValue: RbObjectConvertible) throws -> RbObject {
        try Ruby.setup()
        try name.checkRubyClassVarName()
        try checkClass()

        let id = try Ruby.getID(for: name)

        let newValueObj = newValue.rubyObject
        newValueObj.withRubyValue { rb_cvar_set(getValue(), id, $0) }
        return newValueObj
    }
}

// MARK: - Global Variables

extension RbObjectAccess {
    /// Get the value of a Ruby global variable.
    ///
    /// For a version that does not throw, see `failable`.
    ///
    /// - parameter name: Name of global variable to get.  Must begin with '$'.
    /// - returns: Value of the variable, or Ruby nil if not set before.
    /// - throws: `RbError` if `name` looks wrong.
    ///
    /// (This method is present in this class meaning you can call it on any
    /// `RbObject` as well as `RbBridge` without any difference in effect.  This is
    /// purely convenience to put all these getter/setter pairs in the same place and
    /// make construction of `RbFailableAccess` a bit easier.  Best practice probably
    /// to avoid calling the `RbObject` version.)
    public func getGlobalVar(_ name: String) throws -> RbObject {
        try Ruby.setup()
        try name.checkRubyGlobalVarName()

        return RbObject(rubyValue: name.withCString { rb_gv_get($0) })
    }

    /// Set a Ruby global variable.  Creates a new one if it doesn't exist yet.
    ///
    /// For a version that does not throw, see `failable`.
    ///
    /// - parameter name: Name of global variable to set.  Must begin with '$'.
    /// - parameter newValue: New value to set.
    /// - returns: The value that was set.
    /// - throws: `RbError` if `name` looks wrong.
    ///
    /// (This method is present in this class meaning you can call it on any
    /// `RbObject` as well as `RbBridge` without any difference in effect.  This is
    /// purely convenience to put all these getter/setter pairs in the same place and
    /// make construction of `RbFailableAccess` a bit easier.  Best practice probably
    /// to avoid calling the `RbObject` version.)
    @discardableResult
    public func setGlobalVar(_ name: String, newValue: RbObjectConvertible) throws -> RbObject {
        try Ruby.setup()
        try name.checkRubyGlobalVarName()

        return RbObject(rubyValue: newValue.rubyObject.withRubyValue { rubyValue in
            name.withCString { cstr in
                rb_gv_set(cstr, rubyValue)
            }
        })
    }
}

// MARK: - Polymorphic Getter

extension RbObjectAccess {
    /// Get some kind of Ruby object based on the `name` parameter:
    /// * If `name` starts with a capital letter then access a constant under this object;
    /// * If `name` starts with '@' or '@@' then access an IVar/CVar for a class object;
    /// * If `name` starts with '$' then access a global variable;
    /// * Otherwise call a zero-args method.
    ///
    /// This is a convenience helper to let you access Ruby structures without
    /// worrying about precisely what they are.
    ///
    /// For a version that does not throw, see `failable`.
    ///
    /// - parameter name: Name of thing to access.
    /// - returns: The accessed thing .
    /// - throws: `RbError.rubyException` if Ruby has a problem.
    ///           `RbError` of some other kind if `name` looks wrong in some way.
    @discardableResult
    public func get(_ name: String) throws -> RbObject {
        if name.isRubyConstantName {
            return try getConstant(name)
        } else if name.isRubyGlobalVarName {
            return try getGlobalVar(name)
        } else if name.isRubyInstanceVarName {
            return try getInstanceVar(name)
        } else if name.isRubyClassVarName {
            return try getClassVar(name)
        }
        return try call(name)
    }
}
