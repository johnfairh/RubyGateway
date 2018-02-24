//
//  RbConstantScope.swift
//  RubyBridge
//
//  Distributed under the MIT license, see LICENSE
//

import CRuby
import RubyBridgeHelpers
import Foundation

/// Identify something that can have constants (classes, modules, actual constants)
/// nested under it.  This is either a regular class/module object or Object.class
/// for top-level constants.
protocol RbConstantScope {
    /// Get the value for the module to look relative to
    func constantScopeValue() throws -> VALUE
}

extension RbConstantScope {
    /// Get an `RbObject` that represents a Ruby constant.
    ///
    /// In Ruby constants include things that users think of as constants like
    /// `Math::PI`, classes, and modules.  You can use this routine with
    /// any kind of constant, but see `getClass` for a little more sugar.
    ///
    /// ```swift
    /// let rubyPi = Ruby.getConstant("Math::PI")
    /// let crumbs = rubyPi - Double.pi
    /// ```
    /// This is a dynamic call into Ruby that can cause calls to `const_missing`
    /// and autoloading.
    ///
    /// For a version that does not throw, see `RbBridge.failable` or `RbObject.failable`.
    ///
    /// - throws: `RbException` if the constant cannot be found,
    ///           `RbError` if the constant is found but is not a class.
    ///
    /// - parameter name: The name of the constant to look up.  Can contain '::' sequences
    ///   to drill down through nested classes and modules.
    ///
    ///   If you call this method on an `RbObject` then `name` is resolved like Ruby, looking
    ///   up the inheritance chain if there is no local match.
    ///
    /// - returns: an `RbObject` for the class
    ///
    public func getConstant(name: String) throws -> RbObject {
        var nextValue = try constantScopeValue()
        var first = true
        try name.components(separatedBy: "::").forEach { name in
            let rbId = try Ruby.getID(for: name)
            if first {
                // For the first item in the path, allow a hit here or above in the hierarchy
                nextValue = try RbVM.doProtect {
                    return rbb_const_get_protect(nextValue, rbId, nil)
                }
                first = false
            } else {
                // Once found a place to start, insist on stepping down from there.
                nextValue = try RbVM.doProtect {
                    return rbb_const_get_at_protect(nextValue, rbId, nil)
                }
            }
        }
        return RbObject(rubyValue: nextValue)
    }

    /// Get an `RbObject` that represents a Ruby class.
    ///
    /// - throws: `RbException` if the constant cannot be found,
    ///           `RbError` if the constant is found but is not a class.
    ///
    /// - parameter name: The name of the class to look up.  Can contain '::' sequences
    ///   to drill down through nested classes and modules.
    ///
    ///   If you call this method on an `RbObject` then `name` is relative
    ///   to that object, not the top level.
    ///
    /// - returns: an `RbObject` for the class
    ///
    /// One way of creating an empty array:
    /// ```swift
    /// let arrayClass = ruby.getClass("Array")
    /// let array = arrayClass.call("new")
    /// ```
    ///
    /// This is a dynamic call into Ruby that can cause calls to `const_missing`
    /// and autoloading.
    ///
    /// For a version that does not throw, see `RbBridge.failable` or `RbObject.failable`.
    public func getClass(name: String) throws -> RbObject {
        let obj = try getConstant(name: name)
        guard RB_TYPE_P(obj.rubyValue, .T_CLASS) else {
            throw RbError.notClass("getClass(\(name)) failed, found the constant but it has type \(TYPE(obj.rubyValue).rawValue)")
        }
        return obj
    }
}

// MARK: - FailableConstantScope

protocol RbFailableConstantScope {
    /// The underlying throwing constant scope
    var constantScope: RbConstantScope { get }
}

extension RbFailableConstantScope {
    /// Get an `RbObject` that represents a Ruby constant.
    ///
    /// - parameter name: The name of the constant to look up.
    /// - returns: an `RbObject` for the class or `nil` if an error occurred.
    ///
    /// This is a non-throwing version of `RbConstantScope.getConstant(name:)`.
    public func getConstant(name: String) -> RbObject? {
        return try? constantScope.getConstant(name: name)
    }

    /// Get an `RbObject` that represents a Ruby class.
    ///
    /// - parameter name: The name of the class to look up.
    /// - returns: an `RbObject` for the class or `nil` if an error occurred.
    ///
    /// This is a non-throwing version of `RbConstantScope.getClass(name:)`.
    public func getClass(name: String) -> RbObject? {
        return try? constantScope.getClass(name: name)
    }
}
