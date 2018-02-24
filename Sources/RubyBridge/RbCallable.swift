//
//  RbCallable.swift
//  RubyBridge
//
//  Distributed under the MIT license, see LICENSE
//

import CRuby
import RubyBridgeHelpers

/// Identify something that supports Ruby message delivery
protocol RbCallable {
    /// Get the value to send messages to
    func callableSelfValue() throws -> VALUE
}

extension RbCallable {
    /// Call a Ruby object method
    ///
    /// - parameter method: The name of the method to call
    /// - parameter args: The positional arguments to the method
    /// - parameter kwArgs: The keyword arguments to the method
    /// - returns: The result of calling the method
    /// - throws: `RbException` if there is a Ruby exception.
    ///
    /// TODO: blocks.
    @discardableResult
    public func call(method: String,
                     args: [RbObjectConvertible] = [],
                     kwArgs: [(String, RbObjectConvertible)] = []) throws -> RbObject {
        if kwArgs.count > 0 {
            fatalError("TODO: kwArgs")
        }
        let selfVal = try callableSelfValue()
        let methodId = try Ruby.getID(for: method)
        let argObjects = args.map { $0.rubyObject } // slightly concerned Swift won't keep these alive...
        let argValues = argObjects.map { $0.rubyValue }

        let resultVal = try RbVM.doProtect {
            rbb_funcallv_protect(selfVal, methodId, Int32(argValues.count), argValues, nil)
        }
        return RbObject(rubyValue: resultVal)
    }

    /// Set an attribute of a Ruby object.
    ///
    /// Attributes are declared with `:attr_accessor` and so on -- this routine is a
    /// wrapper around the `attrname=` method.
    ///
    /// - parameter attribute: The name of the attribute to set
    /// - parameter value: The new value of the attribute
    /// - returns: whatever the attribute setter returns, usually the new value
    /// - throws: `RbException` if there is a Ruby exception, probably means `attribute` doesn't exist.
    @discardableResult
    public func set(attribute: String, to value: RbObjectConvertible) throws -> RbObject {
        return try call(method: "\(attribute)=", args: [value])
    }

    /// Get an attribute of a Ruby object.
    ///
    /// Attributes are declared with `:attr_accessor` and so on -- this routine is a
    /// simple wrapper around `call(...)` for symmetry with `set(...)`.
    ///
    /// - parameter attribute: The name of the attribute to get
    /// - returns: The value of the attribute
    /// - throws: `RbException` if there is a Ruby exception, probably means `attribute` doesn't exist.
    public func get(attribute: String) throws -> RbObject {
        return try call(method: attribute)
    }
}

// MARK: - FailableCallable

protocol RbFailableCallable {
    /// The underlying throwing callable
    var callable: RbCallable { get }
}

extension RbFailableCallable {
    /// Get an `RbObject` that represents a Ruby constant.
    ///
    /// - parameter name: The name of the constant to look up.
    /// - returns: an `RbObject` for the class or `nil` if an error occurred.
    ///
    /// This is a non-throwing version of `RbConstantScope.getConstant(name:)`.
    public func call(method: String,
                     args: [RbObjectConvertible] = [],
                     kwArgs: [(String, RbObjectConvertible)] = []) -> RbObject? {
        return try? callable.call(method: method, args: args, kwArgs: kwArgs)
    }

    public func set(attribute: String, to value: RbObjectConvertible) -> RbObject? {
        return call(method: "\(attribute)=", args: [value])
    }

    public func get(attribute: String) -> RbObject? {
        return call(method: attribute)
    }
}
