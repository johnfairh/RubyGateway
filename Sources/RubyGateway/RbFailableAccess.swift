//
//  RbFailableAccess.swift
//  RubyGateway
//
//  Distributed under the MIT license, see LICENSE
//

/// A way to call Ruby methods and so on with a different error-handling style
/// to the try/catch approach of `RbObjectAccess`: the methods return `nil` in failure
/// cases instead of throwing errors.  Get hold of this *failable* interface using
/// `RbObject.failable` or `RbGateway.failable`:
/// ```swift
/// if let classObj = Ruby.failable.getClass("Mod::Service"),
///    let instance = classObj.failable.call("new"),
///    let result = instance.failable.get("summary") {
///    print(result)
/// }
/// ```
/// This interface makes it easier to ignore errors especially on setters where
/// there is often no apparent need to check the result.  This may be construed
/// as a feature; I'm not really convinced it pulls its weight over `try?`.
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

// MARK: - Failable Access

extension RbObjectAccess {
    /// Get a version of this API that returns `nil` instead of throwing errors.
    /// See `RbFailableAccess`.
    public var failable: RbFailableAccess {
        RbFailableAccess(access: self)
    }
}

// MARK: - Method Call

extension RbFailableAccess {
    /// Call a method of a Ruby object.
    ///
    /// This is a non-throwing version of `RbObjectAccess.call(_:args:kwArgs:)`.
    /// See `RbError.history` to retrieve error details.
    ///
    /// - parameter method: The name of the method to call.
    /// - parameter args: The positional arguments to the method, none by default.
    /// - parameter kwArgs: The keyword arguments to the method, none by default.
    /// - returns: An `RbObject` for the result of the method, or `nil` if an error occurred.
    public func call(_ method: String,
                     args: [(any RbObjectConvertible)?] = [],
                     kwArgs: KeyValuePairs<String, (any RbObjectConvertible)?> = [:]) -> RbObject? {
        try? access.call(method, args: args, kwArgs: kwArgs)
    }

    /// Call a method of a Ruby object passing Swift code as a block used immediately.
    ///
    /// This is a non-throwing version of `RbObjectAccess.call(_:args:kwArgs:blockCall:)`.
    /// See `RbError.history` to retrieve error details.
    ///
    /// - parameter method: The name of the method to call.
    /// - parameter args: The positional arguments to the method, none by default.
    /// - parameter kwArgs: The keyword arguments to the method, none by default.
    /// - parameter blockCall: Swift code to pass as a block to the method.
    /// - returns: An `RbObject` for the result of the method, or `nil` if an error occurred.
    public func call(_ method: String,
                     args: [(any RbObjectConvertible)?] = [],
                     kwArgs: KeyValuePairs<String, (any RbObjectConvertible)?> = [:],
                     blockCall: RbBlockCallback) -> RbObject? {
        try? access.call(method, args: args, kwArgs: kwArgs, blockCall: blockCall)
    }

    /// Call a method of a Ruby object passing Swift code as a block.
    ///
    /// This is a non-throwing version of `RbObjectAccess.call(_:args:kwArgs:blockRetention:blockCall:)`.
    /// See `RbError.history` to retrieve error details.
    ///
    /// - parameter method: The name of the method to call.
    /// - parameter args: The positional arguments to the method, none by default.
    /// - parameter kwArgs: The keyword arguments to the method, none by default.
    /// - parameter blockRetention: Should the `blockCall` closure be retained for
    ///             longer than this call?  See `RbBlockRetention`.
    /// - parameter blockCall: Swift code to pass as a block to the method.
    /// - returns: An `RbObject` for the result of the method, or `nil` if an error occurred.
    public func call(_ method: String,
                     args: [(any RbObjectConvertible)?] = [],
                     kwArgs: KeyValuePairs<String, (any RbObjectConvertible)?> = [:],
                     blockRetention: RbBlockRetention,
                     blockCall: @escaping @Sendable RbBlockCallback) -> RbObject? {
        try? access.call(method, args: args, kwArgs: kwArgs, blockRetention: blockRetention, blockCall: blockCall)
    }

    /// Call a method of a Ruby object passing a Ruby Proc as a block.
    ///
    /// This is a non-throwing version of `RbObjectAccess.call(_:args:kwArgs:block:)`.
    /// See `RbError.history` to retrieve error details.
    ///
    /// - parameter method: The name of the method to call.
    /// - parameter args: The positional arguments to the method, none by default.
    /// - parameter kwArgs: The keyword arguments to the method, none by default.
    /// - parameter block: A Ruby proc to pass as a block to the method.
    /// - returns: An `RbObject` for the result of the method, or `nil` if an error occurred.
    public func call(_ method: String,
                     args: [(any RbObjectConvertible)?] = [],
                     kwArgs: KeyValuePairs<String, (any RbObjectConvertible)?> = [:],
                     block: any RbObjectConvertible) -> RbObject? {
        try? access.call(method, args: args, kwArgs: kwArgs, block: block)
    }

    /// Call a method of a Ruby object using a symbol.
    ///
    /// This is a non-throwing version of `RbObjectAccess.call(symbol:args:kwArgs:)`.
    /// See `RbError.history` to retrieve error details.
    ///
    /// - parameter symbol: A symbol for the method to call.
    /// - parameter args: The positional arguments to the method, none by default.
    /// - parameter kwArgs: The keyword arguments to the method, none by default.
    /// - returns: An `RbObject` for the result of the method, or `nil` if an error occurred.
    @discardableResult
    public func call(symbol: any RbObjectConvertible,
                     args: [(any RbObjectConvertible)?] = [],
                     kwArgs: KeyValuePairs<String, (any RbObjectConvertible)?> = [:]) -> RbObject? {
        try? access.call(symbol: symbol, args: args, kwArgs: kwArgs)
    }

    /// Call a method of a Ruby object using a symbol passing Swift code as a block used immediately.
    ///
    /// This is a non-throwing version of `RbObjectAccess.call(symbol:args:kwArgs:blockCall:)`.
    /// See `RbError.history` to retrieve error details.
    ///
    /// - parameter symbol: A symbol for the method to call.
    /// - parameter args: The positional arguments to the method, none by default.
    /// - parameter kwArgs: The keyword arguments to the method, none by default.
    /// - parameter blockCall: Swift code to pass as a block to the method.
    /// - returns: An `RbObject` for the result of the method, or `nil` if an error occurred.
    @discardableResult
    public func call(symbol: any RbObjectConvertible,
                     args: [(any RbObjectConvertible)?] = [],
                     kwArgs: KeyValuePairs<String, (any RbObjectConvertible)?> = [:],
                     blockCall: RbBlockCallback) -> RbObject? {
        try? access.call(symbol: symbol, args: args, kwArgs: kwArgs, blockCall: blockCall)
    }

    /// Call a method of a Ruby object using a symbol passing Swift code as a block.
    ///
    /// This is a non-throwing version of `RbObjectAccess.call(symbol:args:kwArgs:blockRetention:blockCall:)`.
    /// See `RbError.history` to retrieve error details.
    ///
    /// - parameter symbol: A symbol for the method to call.
    /// - parameter args: The positional arguments to the method, none by default.
    /// - parameter kwArgs: The keyword arguments to the method, none by default.
    /// - parameter blockRetention: Should the `blockCall` closure be retained for
    ///             longer than this call?  See `RbBlockRetention`.
    /// - parameter blockCall: Swift code to pass as a block to the method.
    /// - returns: An `RbObject` for the result of the method, or `nil` if an error occurred.
    @discardableResult
    public func call(symbol: any RbObjectConvertible,
                     args: [(any RbObjectConvertible)?] = [],
                     kwArgs: KeyValuePairs<String, (any RbObjectConvertible)?> = [:],
                     blockRetention: RbBlockRetention = .none,
                     blockCall: @escaping @Sendable RbBlockCallback) -> RbObject? {
        try? access.call(symbol: symbol, args: args, kwArgs: kwArgs, blockRetention: blockRetention, blockCall: blockCall)
    }

    /// Call a method of a Ruby object using a symbol passing a Ruby Proc as a block.
    ///
    /// This is a non-throwing version of `RbObjectAccess.call(symbol:args:kwArgs:block:)`.
    /// See `RbError.history` to retrieve error details.
    ///
    /// - parameter symbol: A symbol for the method to call.
    /// - parameter args: The positional arguments to the method, none by default.
    /// - parameter kwArgs: The keyword arguments to the method, none by default.
    /// - parameter block: A Ruby proc to pass as a block to the method.
    /// - returns: An `RbObject` for the result of the method, or `nil` if an error occurred.
    @discardableResult
    public func call(symbol: any RbObjectConvertible,
                     args: [(any RbObjectConvertible)?] = [],
                     kwArgs: KeyValuePairs<String, (any RbObjectConvertible)?> = [:],
                     block: any RbObjectConvertible) -> RbObject? {
        try? access.call(symbol: symbol, args: args, kwArgs: kwArgs, block: block)
    }
}

// MARK: - Attributes

extension RbFailableAccess {
    /// Get an attribute of a Ruby object.
    ///
    /// This is a non-throwing version of `RbObjectAccess.getAttribute(_:)`.
    /// See `RbError.history` to retrieve error details.
    ///
    /// - parameter name: The attribute to access.
    /// - returns: The value of the attribute, or `nil` if an error occurred.
    public func getAttribute(_ name: String) -> RbObject? {
        try? access.getAttribute(name)
    }

    /// Set an attribute of a Ruby object.
    ///
    /// This is a non-throwing version of `RbObjectAccess.setAttribute(_:newValue:)`.
    /// See `RbError.history` to retrieve error details.
    ///
    /// - parameter name: The attribute to set.
    /// - parameter newValue: The new value for the attribute.
    /// - returns: The value set to the attribute, or `nil` if an error occurred.
    public func setAttribute(_ name: String, newValue: (any RbObjectConvertible)?) -> RbObject? {
        try? access.setAttribute(name, newValue: newValue)
    }
}

// MARK: - Constants

extension RbFailableAccess {
    /// Get an `RbObject` that represents a Ruby constant.
    ///
    /// This is a non-throwing version of `RbObjectAccess.getConstant(_:)`.
    /// See `RbError.history` to retrieve error details.
    ///
    /// - parameter name: The name of the constant to look up.
    /// - returns: An `RbObject` for the constant or `nil` if an error occurred.
    public func getConstant(_ name: String) -> RbObject? {
        try? access.getConstant(name)
    }

    /// Get an `RbObject` that represents a Ruby class.
    ///
    /// This is a non-throwing version of `RbObjectAccess.getClass(_:)`.
    /// See `RbError.history` to retrieve error details.
    ///
    /// - parameter name: The name of the class to look up.
    /// - returns: An `RbObject` for the class or `nil` if an error occurred.
    public func getClass(_ name: String) -> RbObject? {
        try? access.getClass(name)
    }

    /// Bind an object to a constant name.
    ///
    /// This is a non-throwing version of `RbObjectAccess.setConstant(_:newValue:)`.
    /// See `RbError.history` to retrieve error details.
    ///
    /// - parameter name: The name of the constant to create or replace.
    /// - parameter newValue: The value for the constant.
    /// - returns: The value set for the constant or `nil` if an error occurred.
    @discardableResult
    public func setConstant(_ name: String, newValue: (any RbObjectConvertible)?) -> RbObject? {
        try? access.setConstant(name, newValue: newValue)
    }
}

// MARK: - Instance Variables

extension RbFailableAccess {
    /// Get the value of a Ruby instance variable.
    ///
    /// This is a non-throwing version of `RbObjectAccess.getInstanceVar(_:)`.
    /// See `RbError.history` to retrieve error details.
    ///
    /// - parameter name: Name of the IVar.  Must begin with a single `@`.
    /// - returns: Value of the IVar, or `nil` if an error occurred.
    public func getInstanceVar(_ name: String) -> RbObject? {
        try? access.getInstanceVar(name)
    }

    /// Set a Ruby instance variable.
    ///
    /// This is a non-throwing version of `RbObjectAccess.setInstanceVar(_:newValue:)`.
    /// See `RbError.history` to retrieve error details.
    ///
    /// - parameter name: Name of the IVar.  Must begin with a single `@`.
    /// - parameter newValue: The new value for the IVar.
    /// - returns: The value that was set, or nil if an error occurred.
    @discardableResult
    public func setInstanceVar(_ name: String, newValue: (any RbObjectConvertible)?) -> RbObject? {
        try? access.setInstanceVar(name, newValue: newValue)
    }
}

// MARK: - Class Variables

extension RbFailableAccess {
    /// Get the value of a Ruby class variable.
    ///
    /// Must be called on an `RbObject` for a class, or `RbGateway`.
    ///
    /// This is a non-throwing version of `RbObjectAccess.getClassVar(_:)`.
    /// See `RbError.history` to retrieve error details.
    ///
    /// - parameter name: Name of the CVar.  Must begin with `@@`.
    /// - returns: Value of the CVar, or `nil` if an error occurred.
    public func getClassVar(_ name: String) -> RbObject? {
        try? access.getClassVar(name)
    }

    /// Set or create a Ruby class variable.
    ///
    /// Must be called on an `RbObject` for a class, or `RbGateway`.
    ///
    /// This is a non-throwing version of `RbObjectAccess.setClassVar(_:newValue:)`.
    /// See `RbError.history` to retrieve error details.
    ///
    /// - parameter name: Name of the CVar.  Must begin with `@@`.
    /// - parameter newValue: The new value for the CVar.
    /// - returns: The value that was set, or `nil` if an error occurred.
    @discardableResult
    public func setClassVar(_ name: String, newValue: (any RbObjectConvertible)?) -> RbObject? {
        try? access.setClassVar(name, newValue: newValue)
    }
}

// MARK: - Global Variables

extension RbFailableAccess {
    /// Get the value of a Ruby global variable.
    ///
    /// This is a non-throwing version of `RbObjectAccess.getGlobalVar(_:)`.
    /// See `RbError.history` to retrieve error details.
    ///
    /// - parameter name: Name of the global variable.  Must begin with `$`.
    /// - returns: Value of the variable, or `nil` if an error occurred.
    public func getGlobalVar(_ name: String) -> RbObject? {
        try? access.getGlobalVar(name)
    }

    /// Set a Ruby global variable.
    ///
    /// This is a non-throwing version of `RbObjectAccess.setGlobalVar(_:newValue:)`.
    /// See `RbError.history` to retrieve error details.
    ///
    /// - parameter name: Name of the global variable.  Must begin with `$`.
    /// - parameter newValue: The new value for the variable.
    /// - returns: The value that was set, or `nil` if an error occurred.
    @discardableResult
    public func setGlobalVar(_ name: String, newValue: (any RbObjectConvertible)?) -> RbObject? {
        try? access.setGlobalVar(name, newValue: newValue)
    }
}

// MARK: - Polymorphic Getter

extension RbFailableAccess {
    /// Get some kind of Ruby object based on the `name` parameter.
    ///
    /// This is a non-throwing version of `RbObjectAccess.get(_:)`.
    /// See `RbError.history` to retrieve error details.
    ///
    /// - parameter name: Name of method / IVar / attribute / CVar / GVar / constant to access.
    /// - returns: Retrieved object, or `nil` if an error occurred.
    @discardableResult
    public func get(_ name: String) -> RbObject? {
        try? access.get(name)
    }
}
