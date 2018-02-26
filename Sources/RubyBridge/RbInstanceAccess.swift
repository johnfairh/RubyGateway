//
//  RbInstanceAccess.swift
//  RubyBridge
//
//  Distributed under the MIT license, see LICENSE
//

import CRuby
import RubyBridgeHelpers

/// Identify something that supports Ruby message delivery
public protocol RbInstanceAccess {
    /// The `VALUE` identifying the object to send messages to
    var rubyValue: VALUE { get }
}

extension RbInstanceAccess {
    /// Call a Ruby object method
    ///
    /// - parameter method: The name of the method to call.
    /// - parameter args: The positional arguments to the method.  None by default.
    /// - parameter kwArgs: The keyword arguments to the method.  None by default.
    /// - returns: The result of calling the method.
    /// - throws: `RbException` if there is a Ruby exception.  No checking here on the
    ///           spelling of `name` on top of that done by Ruby.
    ///
    /// TODO: blocks.
    @discardableResult
    public func call(_ method: String,
                     args: [RbObjectConvertible] = [],
                     kwArgs: [(String, RbObjectConvertible)] = []) throws -> RbObject {
        if kwArgs.count > 0 {
            fatalError("TODO: kwArgs")
        }
        try Ruby.setup()
        let methodId = try Ruby.getID(for: method)
        let argObjects = args.map { $0.rubyObject }
        let resultVal = try argObjects.withRubyValues { argValues in
            try RbVM.doProtect {
                rbb_funcallv_protect(self.rubyValue, methodId, Int32(argValues.count), argValues, nil)
            }
        }

        return RbObject(rubyValue: resultVal)
    }

    /// Set an attribute of a Ruby object.
    ///
    /// Attributes are declared with `:attr_accessor` and so on -- this routine is a
    /// wrapper around the `attrname=` method.
    ///
    /// - parameter name: The name of the attribute to set
    /// - parameter value: The new value of the attribute
    /// - returns: whatever the attribute setter returns, usually the new value
    /// - throws: `RbException` if there is a Ruby exception, probably means `attribute` doesn't exist.
    ///           `RbError` if `name` does not look like a Ruby attribute name.
    @discardableResult
    public func setAttribute(_ name: String, newValue: RbObjectConvertible) throws -> RbObject {
        try name.checkRubyMethodName()
        return try call("\(name)=", args: [newValue])
    }

    /// Get an attribute of a Ruby object.
    ///
    /// Attributes are declared with `:attr_accessor` and so on -- this routine is a
    /// simple wrapper around `call(...)` for symmetry with `set(...)`.
    ///
    /// - parameter name: The name of the attribute to get.
    /// - returns: The value of the attribute.
    /// - throws: `RbException` if there is a Ruby exception, probably means `attribute` doesn't exist.
    ///           `RbError` if `name` does not look like a Ruby attribute name.
    public func getAttribute(_ name: String) throws -> RbObject {
        try name.checkRubyMethodName()
        return try call(name)
    }

    /// Set a Ruby instance variable.  Creates a new one if it doesn't exist yet.
    ///
    /// - parameter name: Name of ivar to set.  Should begin with single `@`.
    /// - parameter newValue: New value to set.
    /// - returns: the value that was set.
    /// - throws: `RbError` if `name` looks wrong. `RbException` if Ruby has a problem.
    ///
    /// Calling this on `RbBridge` is like doing `@f = 3` at the top level, it sets an
    /// instance variable in the `main` object.
    @discardableResult
    public func setInstanceVar(_ name: String, newValue: RbObjectConvertible) throws -> RbObject {
        try Ruby.setup()
        try name.checkRubyInstanceVarName()
        let id = try Ruby.getID(for: name)

        return RbObject(rubyValue: newValue.rubyObject.withRubyValue { newRubyValue in
            return rb_ivar_set(rubyValue, id, newRubyValue)
        })
    }

    /// Get the value of a Ruby instance variable.  Creates a new one with a nil value
    /// if it doesn't exist yet.
    ///
    /// - parameter name: Name of ivar to get.  Should begin with single `@`.
    /// - returns: Value of the ivar or nil if it has not been assigned yet.
    /// - throws: `RbError` if `name` looks wrong. `RbException` if Ruby has a problem.
    ///
    /// Calling this on `RbBridge` is like doing `@f` at the top level, it gets an
    /// instance variable from the `main` object.
    public func getInstanceVar(_ name: String) throws -> RbObject {
        try Ruby.setup()
        try name.checkRubyInstanceVarName()
        let id = try Ruby.getID(for: name)

        return RbObject(rubyValue: rb_ivar_get(rubyValue, id))
    }

    /// Set a Ruby global variable.  Creates a new one if it doesn't exist yet.
    ///
    /// - parameter name: Name of global variable to set.  Should begin with `$`.
    /// - parameter newValue: New value to set.
    /// - returns: The value that was set.
    /// - throws: `RbError` if `name` looks wrong.
    ///
    /// (This method is present in this protocol meaning you can call it on any
    /// `RbObject` as well as `RbBridge` without any difference in effect.  This is
    /// purely convenience to put all these getter/setter pairs in the same place and
    /// make construction of `RbFailableAccess` a bit easier.  Best practice probably
    /// to avoid calling the `RbObject` version.)
    @discardableResult
    public func setGlobalVar(_ name: String, newValue: RbObjectConvertible) throws -> RbObject {
        try Ruby.setup()
        try name.checkRubyGlobalVarName()

        return RbObject(rubyValue: newValue.rubyObject.withRubyValue { rubyValue in
            return name.withCString { cstr in
                return rb_gv_set(cstr, rubyValue)
            }
        })
    }

    /// Get the value of a Ruby global variable.
    ///
    /// - parameter name: Name of global variable to get.  Should begin with `$`.
    /// - returns: Value of the variable, or Ruby nil if not set before.
    /// - throws: `RbError` if `name` looks wrong.
    ///
    /// (This method is present in this protocol meaning you can call it on any
    /// `RbObject` as well as `RbBridge` without any difference in effect.  This is
    /// purely convenience to put all these getter/setter pairs in the same place and
    /// make construction of `RbFailableAccess` a bit easier.  Best practice probably
    /// to avoid calling the `RbObject` version.)
    public func getGlobalVar(_ name: String) throws -> RbObject {
        try Ruby.setup()
        try name.checkRubyGlobalVarName()

        return RbObject(rubyValue: name.withCString { cstr in
            rb_gv_get(cstr)
        })
    }
}

extension RbInstanceAccess where Self: RbConstantAccess {
    /// Get some kind of Ruby object based on the `name` parameter:
    /// * If it starts with a capital letter then access a constant under this object;
    /// * If it starts with @ or @@ then access an ivar/cvar for a class object;
    /// * If it starts with $ then access a global variable;
    /// * Otherwise call a zero-args method.
    ///
    /// This is a convenience helper to let you access Ruby structures without
    /// worrying about precisely what they are.
    ///
    /// - parameter name: Name to access.
    /// - throws: `RbError` if the name is wrong for the object; `RbException` if
    ///           something goes wrong in Ruby.
    @discardableResult
    public func get(_ name: String) throws -> RbObject {
        if name.isRubyConstantName {
            return try getConstant(name)
        } else if name.isRubyGlobalVarName {
            return try getGlobalVar(name)
        } else if name.isRubyInstanceVarName {
            return try getInstanceVar(name)
        }
        return try call(name)
    }
}

fileprivate extension RbObject {
    func withRubyValue<T>(call: (VALUE) throws -> T) rethrows -> T {
        return try call(rubyValue)
    }
}

fileprivate extension Array where Element == RbObject {
    // Helper to get hold of the `VALUE`s associated with an array of `RbObject`s
    // This prevents Swift from dealloc'ing the `RbObject` before we are done
    // with the `VALUE`s.
    func withRubyValues<T>(call: ([VALUE]) throws -> T) rethrows -> T {
        return try call(map { $0.rubyValue })
    }
}
