//
//  RbFailableAccess.swift
//  RubyBridge
//
//  Distributed under the MIT license, see LICENSE
//


protocol RbFailableAccess {
    /// The underlying throwing callable
    var access: RbInstanceAccess { get }
}

extension RbFailableAccess {
    public func call(_ method: String,
                     args: [RbObjectConvertible] = [],
                     kwArgs: [(String, RbObjectConvertible)] = []) -> RbObject? {
        return try? access.call(method, args: args, kwArgs: kwArgs)
    }

    public func setAttribute(_ name: String, newValue: RbObjectConvertible) -> RbObject? {
        return try? access.setAttribute(name, newValue: newValue)
    }

    public func getAttribute(_ name: String) -> RbObject? {
        return try? access.getAttribute(name)
    }
}

protocol RbFailableConstantScope {
    /// The underlying throwing constant scope
    var constantScope: RbConstantAccess { get }
}

extension RbFailableConstantScope {
    /// Get an `RbObject` that represents a Ruby constant.
    ///
    /// - parameter name: The name of the constant to look up.
    /// - returns: an `RbObject` for the class or `nil` if an error occurred.
    ///
    /// This is a non-throwing version of `RbConstantScope.getConstant(name:)`.
    public func getConstant(_ name: String) -> RbObject? {
        return try? constantScope.getConstant(name)
    }

    /// Get an `RbObject` that represents a Ruby class.
    ///
    /// - parameter name: The name of the class to look up.
    /// - returns: an `RbObject` for the class or `nil` if an error occurred.
    ///
    /// This is a non-throwing version of `RbConstantScope.getClass(name:)`.
    public func getClass(_ name: String) -> RbObject? {
        return try? constantScope.getClass(name)
    }
}
