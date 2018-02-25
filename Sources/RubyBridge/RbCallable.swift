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

extension Array where Element == RbObject {
    // Helper to get hold of the `VALUE`s associated with an array of `RbObject`s
    // This prevents Swift from dealloc'ing the `RbObject` before we are done
    // with the `VALUE`s.
    func withRubyValues<T>(call: ([VALUE]) throws -> T) rethrows -> T {
        return try call(map { $0.rubyValue })
    }
}

extension RbCallable {
    /// Call a Ruby object method
    ///
    /// - parameter method: The name of the method to call.
    /// - parameter args: The positional arguments to the method.  None by default.
    /// - parameter kwArgs: The keyword arguments to the method.  None by default.
    /// - returns: The result of calling the method.
    /// - throws: `RbException` if there is a Ruby exception.
    ///
    /// TODO: blocks.
    @discardableResult
    public func call(_ method: String,
                     args: [RbObjectConvertible] = [],
                     kwArgs: [(String, RbObjectConvertible)] = []) throws -> RbObject {
        if kwArgs.count > 0 {
            fatalError("TODO: kwArgs")
        }
        let selfVal = try callableSelfValue()
        let methodId = try Ruby.getID(for: method)
        let argObjects = args.map { $0.rubyObject }
        let resultVal = try argObjects.withRubyValues { argValues in
            try RbVM.doProtect {
                rbb_funcallv_protect(selfVal, methodId, Int32(argValues.count), argValues, nil)
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
    @discardableResult
    public func setAttribute(_ name: String, newValue: RbObjectConvertible) throws -> RbObject {
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
    public func getAttribute(_ name: String) throws -> RbObject {
        return try call(name)
    }
}

// MARK: - FailableCallable

protocol RbFailableCallable {
    /// The underlying throwing callable
    var callable: RbCallable { get }
}

extension RbFailableCallable {
    public func call(_ method: String,
                     args: [RbObjectConvertible] = [],
                     kwArgs: [(String, RbObjectConvertible)] = []) -> RbObject? {
        return try? callable.call(method, args: args, kwArgs: kwArgs)
    }

    public func setAttribute(_ name: String, newValue: RbObjectConvertible) -> RbObject? {
        return call("\(name)=", args: [newValue])
    }

    public func getAttribute(_ name: String) -> RbObject? {
        return call(name)
    }
}
