//
//  RbFailableAccess.swift
//  RubyBridge
//
//  Distributed under the MIT license, see LICENSE
//

/// An interface to call Ruby methods and so on with a different error-handling style
/// to the try/catch approach of `RbObjectAccess`: the methods return `nil` in failure
/// cases instead of throwing errors.  Get hold of this *failable* interface using
/// `RbObject.failable` or `RbBridge.failable`:
/// ```swift
/// if let classObj = Ruby.failable.getClass("Mod::Service"),
///    let instance = classObj.failable.call("new"),
///    let result = instance.failable.get("summary") {
///    print(result)
/// }
/// ```
/// This interface makes it easier to ignore errors.  This may be construed as a feature.
///
/// If any methods in this interface do return `nil` then an `RbError` has been raised
/// and suppressed.  You can access the most recent `RbError`s whether suppressed or not
/// via `RbError.history`.
public struct RbFailableAccess {
    /// The underlying throwing accessor
    private var access: RbObjectAccess

    /// Create a new failable access interface to an object.
    init(access: RbObjectAccess) {
        self.access = access
    }
}

// MARK: - Failable access

extension RbObjectAccess {
    /// Get a version of this API that returns `nil` instead of throwing errors.
    /// See `RbFailableAccess`.
    public var failable: RbFailableAccess {
        return RbFailableAccess(access: self)
    }
}

// MARK: - Method call / msg send

extension RbFailableAccess {
    /// Call a method of a Ruby object.
    ///
    /// This is a non-throwing version of `RbObjectAccess.call(method:args:kwArgs:)`.
    /// See `RbError.history` to retrieve error details.
    ///
    /// - parameter method: The name of the method to call.
    /// - parameter args: The positional arguments to the method, none by default.
    /// - parameter kwArgs: The keyword arguments to the method, none by default.
    /// - returns: an `RbObject` for the result of the method, or `nil` if an error occurred.
    public func call(_ method: String,
                     args: [RbObjectConvertible] = [],
                     kwArgs: [(String, RbObjectConvertible)] = []) -> RbObject? {
        return try? access.call(method, args: args, kwArgs: kwArgs)
    }

    /// Call a method of a Ruby object using a symbol.
    ///
    /// This is a non-throwing version of `RbObjectAccess.call(symbol:args:kwArgs:)`.
    /// See `RbError.history` to retrieve error details.
    ///
    /// - parameter symbol: A symbol for the method to call.
    /// - parameter args: The positional arguments to the method, none by default.
    /// - parameter kwArgs: The keyword arguments to the method, none by default.
    /// - returns: an `RbObject` for the result of the method, or `nil` if an error occurred.
    @discardableResult
    public func call(symbol: RbObject,
                     args: [RbObjectConvertible] = [],
                     kwArgs: [(String, RbObjectConvertible)] = []) -> RbObject? {
        return try? access.call(symbol: symbol, args: args, kwArgs: kwArgs)
    }

    /// Get an attribute of a Ruby object.
    ///
    /// This is a non-throwing version of `RbObjectAccess.getAttribute(name:)`.
    /// See `RbError.history` to retrieve error details.
    ///
    /// - parameter name: The attribute to access.
    /// - returns: the value of the attribute, or `nil` if an error occurred.
    public func getAttribute(_ name: String) -> RbObject? {
        return try? access.getAttribute(name)
    }

    /// Set an attribute of a Ruby object.
    ///
    /// This is a non-throwing version of `RbObjectAccess.setAttribute(name:newValue:)`.
    /// See `RbError.history` to retrieve error details.
    ///
    /// - parameter name: The attribute to set.
    /// - parameter newValue: The new value for the attribute.
    /// - returns: the value set to the attribute, or `nil` if an error occurred.
    public func setAttribute(_ name: String, newValue: RbObjectConvertible) -> RbObject? {
        return try? access.setAttribute(name, newValue: newValue)
    }
}

// MARK: - Constants

extension RbFailableAccess {
    /// Get an `RbObject` that represents a Ruby constant.
    ///
    /// This is a non-throwing version of `RbObjectAccess.getConstant(name:)`.
    /// See `RbError.history` to retrieve error details.
    ///
    /// - parameter name: The name of the constant to look up.
    /// - returns: an `RbObject` for the class or `nil` if an error occurred.
    public func getConstant(_ name: String) -> RbObject? {
        return try? access.getConstant(name)
    }

    /// Get an `RbObject` that represents a Ruby class.
    ///
    /// This is a non-throwing version of `RbObjectAccess.getClass(name:)`.
    /// See `RbError.history` to retrieve error details.
    ///
    /// - parameter name: The name of the class to look up.
    /// - returns: an `RbObject` for the class or `nil` if an error occurred.
    public func getClass(_ name: String) -> RbObject? {
        return try? access.getClass(name)
    }
}

// MARK: - IVars

extension RbFailableAccess {
    /// Get the value of a Ruby instance variable.
    ///
    /// This is a non-throwing version of `RbObjectAccess.getInstanceVar(name:)`.
    /// See `RbError.history` to retrieve error details.
    ///
    /// - parameter name: Name of ivar to get.  Must begin with a single `@`.
    /// - returns: Value of the ivar, or `nil` if an error occurred.
    public func getInstanceVar(_ name: String) -> RbObject? {
        return try? access.getInstanceVar(name)
    }

    /// Set a Ruby instance variable.
    ///
    /// This is a non-throwing version of `RbObjectAccess.setInstanceVar(name:)`.
    /// See `RbError.history` to retrieve error details.
    ///
    /// - parameter name: Name of ivar to set.  Must begin with a single `@`.
    /// - parameter newValue: New value to set.
    /// - returns: The value that was set, or nil if an error occurred.
    @discardableResult
    public func setInstanceVar(_ name: String, newValue: RbObjectConvertible) -> RbObject? {
        return try? access.setInstanceVar(name, newValue: newValue)
    }
}

// MARK: - CVars

extension RbFailableAccess {
    /// Get the value of a Ruby class variable.
    ///
    /// Must be called on an `RbObject` for a class, or `RbBridge`.
    ///
    /// This is a non-throwing version of `RbObjectAccess.getClassVar(name:)`.
    /// See `RbError.history` to retrieve error details.
    ///
    /// - parameter name: Name of cvar to get.  Must begin with `@@`.
    /// - returns: Value of the cvar, or `nil` if an error occurred.
    public func getClassVar(_ name: String) -> RbObject? {
        return try? access.getClassVar(name)
    }

    /// Set or create a Ruby class variable.
    ///
    /// Must be called on an `RbObject` for a class, or `RbBridge`.
    ///
    /// This is a non-throwing version of `RbObjectAccess.setClassVar(name:newValue:)`.
    /// See `RbError.history` to retrieve error details.
    ///
    /// - parameter name: Name of cvar to set.  Must begin with `@@`.
    /// - parameter newValue: New value to set.
    /// - returns: the value that was set, or `nil` if an error occurred.
    @discardableResult
    public func setClassVar(_ name: String, newValue: RbObjectConvertible) -> RbObject? {
        return try? access.setClassVar(name, newValue: newValue)
    }
}

// MARK: - Global Vars

extension RbFailableAccess {
    /// Get the value of a Ruby global variable.
    ///
    /// This is a non-throwing version of `RbObjectAccess.getGlobalVar(name:)`.
    /// See `RbError.history` to retrieve error details.
    ///
    /// - parameter name: Name of global variable to get.  Must begin with `$`.
    /// - returns: Value of the variable, or `nil` if an error occurred.
    public func getGlobalVar(_ name: String) -> RbObject? {
        return try? access.getGlobalVar(name)
    }

    /// Set a Ruby global variable.
    ///
    /// This is a non-throwing version of `RbObjectAccess.setGlobalVar(name:newValue:)`.
    /// See `RbError.history` to retrieve error details.
    ///
    /// - parameter name: Name of global variable to set.  Must begin with `$`.
    /// - parameter newValue: New value to set.
    /// - returns: The value that was set, or `nil` if an error occurred.
    @discardableResult
    public func setGlobalVar(_ name: String, newValue: RbObjectConvertible) -> RbObject? {
        return try? access.setGlobalVar(name, newValue: newValue)
    }
}

// MARK: - Polymorphic getter

extension RbFailableAccess {
    /// Get some kind of Ruby object based on the `name` parameter.
    ///
    /// This is a non-throwing version of `RbObjectAccess.get(name:)`.
    /// See `RbError.history` to retrieve error details.
    ///
    /// - parameter name: Name of method / ivar / attribute / cvar / constant to access.
    /// - returns: Retrieved object, or nil if an error occurred.
    @discardableResult
    public func get(_ name: String) -> RbObject? {
        return try? access.get(name)
    }
}
