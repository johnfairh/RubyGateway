//
//  RbObjectAccess.swift
//  RubyGateway
//
//  Distributed under the MIT license, see LICENSE
//

import CRuby
import RubyGatewayHelpers

/// Provides services to manipulate a Ruby object:
/// * Call methods;
/// * Access properties and instance variables;
/// * Access class variables;
/// * Access global variables;
/// * Find constants, classes, and modules.
///
/// The class is abstract.  You use it via `RbObject` and the global `Ruby` instance
/// of `RbGateway`.
///
/// By default all methods throw `RbError`s if anything goes wrong including
/// when Ruby raises an exception.  Use the `RbObjectAccess.failable` adapter to
/// access an alternative API that returns `nil` on errors instead.  You can still
/// see any Ruby exceptions via `RbError.history`.
///
/// ## Calling methods
///
/// Ruby has a few different ways to call methods that are reflected in the
/// various Swift methods here and their types.  The degrees of freedom are:
/// 1. Call method by name or by symbol;
/// 2. Pass positional and/or keyword arguments;
/// 3. Optionally pass a block that can be expressed as a Swift function or
///    a Ruby Proc.
/// 4. Method can either raise an exception or return a value.
///
/// From the simple:
/// ```swift
/// try! obj.call("myMethod")
/// ```
/// ...to more baroque:
/// ```swift
/// do {
///     let result =
///          try obj.call(symbol: myMethodSymbol,
///                       args: [1, "3.5", myHash],
///                       kwArgs: [("mode", RbSymbol("debug")]) { blockArgs in
///                           blockArgs.forEach {
///                               process($0)
///                           }
///                           return .nilObject
///                       }
/// } catch RbError.rubyException(let exn) {
///     handleErrors(error)
/// } catch {
///     ...
/// }
/// ```
public class RbObjectAccess {
    /// Getter for the `VALUE` associated with this object
    private let getValue: () -> VALUE

    /// Swift objects whose lifetimes need to be tied to this one.
    internal private(set) var associatedObjects: [AnyObject]?

    /// Set up Swift access to a Ruby object.
    /// - parameter getValue: Getter for the `VALUE` to be accessed.
    /// - parameter associatedObjects: Set of objects to reference.
    init(getValue: @escaping () -> VALUE, associatedObjects: [AnyObject]? = nil) {
        self.getValue = getValue
        self.associatedObjects = associatedObjects
    }

    /// Add a Swift object to be forgotten about when this one is.
    func associate(object: AnyObject) {
        if associatedObjects != nil {
            associatedObjects?.append(object)
        } else {
            associatedObjects = [object]
        }
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
    /// - throws: `RbError.badIdentifier(type:id:)` if `name` looks wrong.
    ///           `RbError.rubyException(_:)` if Ruby has a problem.
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
    /// - throws: `RbError.badIdentifier(type:id:)` if `name` looks wrong.
    ///           `RbError.rubyException(_:)` if Ruby has a problem.
    @discardableResult
    public func setInstanceVar(_ name: String, newValue: RbObjectConvertible?) throws -> RbObject {
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
    /// - throws: `RbError.rubyException(_:)` if the constant cannot be found.
    public func getConstant(_ name: String) throws -> RbObject {
        try Ruby.setup()
        try name.checkRubyConstantPath()

        var nextValue = getValue()

        try name.components(separatedBy: "::").forEach { name in
            let rbId = try Ruby.getID(for: name)
            if nextValue == getValue() {
                // For the first item in the path, allow a hit here or above in the hierarchy
                nextValue = try RbVM.doProtect { tag in
                    rbg_const_get_protect(nextValue, rbId, &tag)
                }
            } else {
                // Once found a place to start, insist on stepping down from there.
                nextValue = try RbVM.doProtect { tag in
                    rbg_const_get_at_protect(nextValue, rbId, &tag)
                }
            }
        }
        return RbObject(rubyValue: nextValue)
    }

    /// Bind an object to a constant name.
    ///
    /// Use this to add value-constants to the class/module name hierarchy.  For example:
    /// ```swift
    /// let defaultInvader = RbObject(ofClass: "Invader", kwArgs: ["name" : "Zaltor"])
    /// try Ruby.setConstant("Game::Invaders::DEFAULT", defaultInvader)
    /// ```
    ///
    /// To define new classes and modules, use `RbGateway.defineClass(...)` and
    /// `RbGateway.defineModule(...)` instead of this method.
    ///
    /// For a version that does not throw, see `failable`.
    ///
    /// - parameter name: The name of the constant to create or replace.  Can contain '::' sequences
    ///   to drill down through nested classes and modules.
    /// - parameter newValue: The value for the constant.
    /// - returns: The value set for the constant.
    /// - throws: `RbError.badIdentifier(type:id:)` if `name` looks wrong.
    ///           `rubyException(_:)` if there is a Ruby exception.
    ///           `RbError.badType(_:)` if the current object is not a class or module.
    @discardableResult
    public func setConstant(_ name: String, newValue: RbObjectConvertible?) throws -> RbObject {
        try Ruby.setup()
        try name.checkRubyConstantPath()

        let components = name.components(separatedBy: "::")

        let constName = components.last!
        let constId = try Ruby.getID(for: constName)

        let rubyClass: RbObject
        if components.count > 1 {
            rubyClass = try getConstant(components.dropLast().joined(separator: "::"))
        } else {
            rubyClass = RbObject(rubyValue: getValue())
            try rubyClass.checkIsClassOrModule()
        }

        let constObject = newValue.rubyObject
        try rubyClass.withRubyValue { clazzValue in
            try constObject.withRubyValue { constValue in
                try RbVM.doProtect { tag in
                    rbg_const_set_protect(clazzValue, constId, constValue, &tag)
                }
            }
        }

        return constObject
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
    /// - throws: `RbError.rubyException(_:)` if the constant cannot be found.
    ///           `RbError.badType(_:)` if the constant is found but is not a class.
    public func getClass(_ name: String) throws -> RbObject {
        let obj = try getConstant(name)
        try obj.checkIsClass()
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
    /// - throws: `RbError.rubyException(_:)` if there is a Ruby exception.
    ///           `RbError.duplicateKwArg(_:)` if there are duplicate keywords in `kwArgs`.
    ///
    /// For a version that does not throw, see `failable`.
    @discardableResult
    public func call(_ methodName: String,
                     args: [RbObjectConvertible?] = [],
                     kwArgs: KeyValuePairs<String, RbObjectConvertible?> = [:]) throws -> RbObject {
        try Ruby.setup()
        let methodId = try Ruby.getID(for: methodName)
        return try doCall(id: methodId, args: args, kwArgs: kwArgs)
    }

    /// Call a Ruby object method passing Swift code as a block.
    ///
    /// - parameter methodName: The name of the method to call.
    /// - parameter args: The positional arguments to the method.  None by default.
    /// - parameter kwArgs: The keyword arguments to the method.  None by default.
    /// - parameter blockRetention: Should the `blockCall` closure be retained for
    ///             longer than this call?  Default `.none`.  See `RbBlockRetention`.
    /// - parameter blockCall: Swift code to pass as a block to the method.
    /// - returns: The result of calling the method.
    /// - throws: `RbError.rubyException(_:)` if there is a Ruby exception.
    ///           `RbError.duplicateKwArg(_:)` if there are duplicate keywords in `kwArgs`.
    ///
    /// For a version that does not throw, see `failable`.
    @discardableResult
    public func call(_ methodName: String,
                     args: [RbObjectConvertible?] = [],
                     kwArgs: KeyValuePairs<String, RbObjectConvertible?> = [:],
                     blockRetention: RbBlockRetention = .none,
                     blockCall: @escaping RbBlockCallback) throws -> RbObject {
        try Ruby.setup()
        let methodId = try Ruby.getID(for: methodName)
        return try doCall(id: methodId,
                          args: args, kwArgs: kwArgs,
                          blockRetention: blockRetention,
                          blockCall: blockCall)
    }

    /// Call a Ruby object method passing a Ruby Proc as a block.
    ///
    /// - parameter methodName: The name of the method to call.
    /// - parameter args: The positional arguments to the method.  None by default.
    /// - parameter kwArgs: The keyword arguments to the method.  None by default.
    /// - parameter block: A Ruby proc to pass as a block to the method.
    /// - returns: The result of calling the method.
    /// - throws: `RbError.rubyException(_:)` if there is a Ruby exception.
    ///           `RbError.duplicateKwArg(_:)` if there are duplicate keywords in `kwArgs`.
    ///           `RbError.badType(_:)` if `block` does not convert to a Proc.
    ///
    /// For a version that does not throw, see `failable`.
    @discardableResult
    public func call(_ methodName: String,
                     args: [RbObjectConvertible?] = [],
                     kwArgs: KeyValuePairs<String, RbObjectConvertible?> = [:],
                     block: RbObjectConvertible) throws -> RbObject {
        try Ruby.setup()
        let methodId = try Ruby.getID(for: methodName)
        return try doCall(id: methodId, args: args, kwArgs: kwArgs, block: block)
    }

    /// Call a Ruby object method using a symbol.
    ///
    /// - parameter symbol: The symbol for the name of the method to call.
    /// - parameter args: The positional arguments to the method.  None by default.
    /// - parameter kwArgs: The keyword arguments to the method.  None by default.
    /// - returns: The result of calling the method.
    /// - throws: `RbError.rubyException(_:)` if there is a Ruby exception.
    ///           `RbError.badType(_:)` if `symbol` is not a symbol.
    ///           `RbError.duplicateKwArg(_:)` if there are duplicate keywords in `kwArgs`.
    ///
    /// For a version that does not throw, see `failable`.
    @discardableResult
    public func call(symbol: RbObjectConvertible,
                     args: [RbObjectConvertible?] = [],
                     kwArgs: KeyValuePairs<String, RbObjectConvertible?> = [:]) throws -> RbObject {
        try Ruby.setup()
        return try symbol.rubyObject.withSymbolId { methodId in
            try doCall(id: methodId, args: args, kwArgs: kwArgs)
        }
    }

    /// Call a Ruby object method using a symbol passing Swift code as a block.
    ///
    /// - parameter symbol: The symbol for the name of the method to call.
    /// - parameter args: The positional arguments to the method.  None by default.
    /// - parameter kwArgs: The keyword arguments to the method.  None by default.
    /// - parameter blockRetention: Should the `blockCall` closure be retained for
    ///             longer than this call?  Default `.none`.  See `RbBlockRetention`.
    /// - parameter blockCall: Swift code to pass as a block to the method.
    /// - returns: The result of calling the method.
    /// - throws: `RbError.rubyException(_:)` if there is a Ruby exception.
    ///           `RbError.badType(_:)` if `symbol` is not a symbol.
    ///           `RbError.duplicateKwArg(_:)` if there are duplicate keywords in `kwArgs`.
    ///
    /// For a version that does not throw, see `failable`.
    @discardableResult
    public func call(symbol: RbObjectConvertible,
                     args: [RbObjectConvertible?] = [],
                     kwArgs: KeyValuePairs<String, RbObjectConvertible?> = [:],
                     blockRetention: RbBlockRetention = .none,
                     blockCall: @escaping RbBlockCallback) throws -> RbObject {
        try Ruby.setup()
        return try symbol.rubyObject.withSymbolId { methodId in
            try doCall(id: methodId, args: args, kwArgs: kwArgs, blockRetention: blockRetention, blockCall: blockCall)
        }
    }

    /// Call a Ruby object method using a symbol passing a Ruby Proc as a block.
    ///
    /// - parameter symbol: The symbol for the name of the method to call.
    /// - parameter args: The positional arguments to the method.  None by default.
    /// - parameter kwArgs: The keyword arguments to the method.  None by default.
    /// - parameter block: A Ruby proc to pass as a block to the method.
    /// - returns: The result of calling the method.
    /// - throws: `RbError.rubyException(_:)` if there is a Ruby exception.
    ///           `RbError.badType(_:)` if `symbol` is not a symbol.
    ///           `RbError.duplicateKwArg(_:)` if there are duplicate keywords in `kwArgs`.
    ///           `RbError.badType(_:)` if `block` does not convert to a Proc.
    ///
    /// For a version that does not throw, see `failable`.
    @discardableResult
    public func call(symbol: RbObjectConvertible,
                     args: [RbObjectConvertible?] = [],
                     kwArgs: KeyValuePairs<String, RbObjectConvertible?> = [:],
                     block: RbObjectConvertible) throws -> RbObject {
        try Ruby.setup()
        return try symbol.rubyObject.withSymbolId { methodId in
            try doCall(id: methodId, args: args, kwArgs: kwArgs, block: block)
        }
    }

    /// Backend to method-call / message-send.
    private func doCall(id: ID, 
                        args: [RbObjectConvertible?],
                        kwArgs: KeyValuePairs<String, RbObjectConvertible?>,
                        blockRetention: RbBlockRetention = .none,
                        block: RbObjectConvertible? = nil,
                        blockCall: RbBlockCallback? = nil) throws -> RbObject {
        // Sort out unlikely block errors
        let blockObj: RbObject?
        if let block = block {
            blockObj = block.rubyObject
            try blockObj?.checkIsProc()
        } else {
            blockObj = nil
        }

        // Decode arguments
        var argObjects = args.map { $0.rubyObject }
        let hasKwArgs = kwArgs.count > 0

        if hasKwArgs {
            try argObjects.append(RbObjectAccess.buildKwArgsHash(from: kwArgs))
        }

        // Do call - more complicated if block is involved
        return try argObjects.withRubyValues { argValues -> RbObject in
            if let blockCall = blockCall {
                let (context, value) =
                    try RbBlock.doBlockCall(value: getValue(), methodId: id,
                                            argValues: argValues,
                                            hasKwArgs: hasKwArgs,
                                            blockCall: blockCall)

                let retObject = RbObject(rubyValue: value)

                switch blockRetention {
                case .none: break
                case .self: associate(object: context)
                case .returned: retObject.associate(object: context)
                }
                return retObject
            } else if let blockObj = blockObj {
                return RbObject(rubyValue: try blockObj.withRubyValue { blockValue in
                    try RbBlock.doBlockCall(value: getValue(), methodId: id,
                                            argValues: argValues,
                                            hasKwArgs: hasKwArgs,
                                            block: blockValue)
                })
            }
            return RbObject(rubyValue: try RbVM.doProtect { tag in
                rbg_funcallv_protect(getValue(), id,
                                     Int32(argValues.count), argValues,
                                     hasKwArgs ? 1 : 0,
                                     &tag)
            })
        }
    }

    /// Helper to massage Swift-format args ready for the API
    internal static func flattenArgs(args: [RbObjectConvertible?],
                                     kwArgs: KeyValuePairs<String, RbObjectConvertible?>) throws -> [RbObject] {

        var argObjects = args.map { $0.rubyObject }

        if kwArgs.count > 0 {
            try argObjects.append(buildKwArgsHash(from: kwArgs))
        }
        return argObjects
    }

    /// Build a keyword args hash.  The keys are Symbols of the keywords.
    private static func buildKwArgsHash(from kwArgs: KeyValuePairs<String, RbObjectConvertible?>) throws -> RbObject {
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
}

// MARK: - Attributes

extension RbObjectAccess {
    /// Get an attribute of a Ruby object.
    ///
    /// Attributes are declared with `:attr_accessor` and so on -- this routine is a
    /// simple wrapper around `call(...)` for symmetry with `setAttribute(...)`.
    ///
    /// For a version that does not throw, see `failable`.
    ///
    /// - parameter name: The name of the attribute to get.
    /// - returns: The value of the attribute.
    /// - throws: `RbError.badIdentifier(type:id:)` if `name` looks wrong.
    ///           `RbError.rubyException(_:)` if Ruby has a problem, probably means
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
    /// - throws: `RbError.badIdentifier(type:id:)` if `name` looks wrong.
    ///           `RbError.rubyException(_:)` if Ruby has a problem, probably means
    ///           `attribute` doesn't exist.
    @discardableResult
    public func setAttribute(_ name: String, newValue: RbObjectConvertible?) throws -> RbObject {
        try name.checkRubyMethodName()
        return try call("\(name)=", args: [newValue])
    }
}

// MARK: - Class Variables

extension RbObjectAccess {
    /// Check the associated rubyValue is for a class.
    private func hasClassVars() throws {
        let type = TYPE(getValue())
        guard type == .T_CLASS || type == .T_MODULE || type == .T_ICLASS else {
            try RbError.raise(error: .badType("\(getValue()) is not a class, cannot get/setClassVar() on it."))
        }
    }

    /// Get the value of a Ruby class variable that has already been written.
    ///
    /// Must be called on an `RbObject` for a class, or `RbGateway`.  **Note** this
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
    /// - throws: `RbError.badIdentifier(type:id:)` if `name` looks wrong.
    ///           `RbError.badType(_:)` if the object is not a class.
    ///           `RbError.rubyException(_:)` if Ruby has a problem -- in particular,
    ///           if the CVar does not exist.
    public func getClassVar(_ name: String) throws -> RbObject {
        try Ruby.setup()
        try name.checkRubyClassVarName()
        try hasClassVars()

        let id = try Ruby.getID(for: name)

        return try RbObject(rubyValue: RbVM.doProtect { tag in
            rbg_cvar_get_protect(getValue(), id, &tag)
        })
    }

    /// Set a Ruby class variable.  Creates a new one if it doesn't exist yet.
    ///
    /// Must be called on an `RbObject` for a class, or `RbGateway`.  **Note** this
    /// is different from Ruby as-written where you write `@@fred = thing` in an
    /// object context to set a CVar on the object's class.
    ///
    /// For a version that does not throw, see `failable`.
    ///
    /// - parameter name: Name of the CVar to set.  Must begin with '@@'.
    /// - parameter newValue: The new value to set.
    /// - returns: The value that was set.
    /// - throws: `RbError.badIdentifier(type:id:)` if `name` looks wrong.
    ///           `RbError.badType(_:)` if the object is not a class.
    ///           `RbError.rubyException(_:)` if Ruby has a problem.
    @discardableResult
    public func setClassVar(_ name: String, newValue: RbObjectConvertible?) throws -> RbObject {
        try Ruby.setup()
        try name.checkRubyClassVarName()
        try hasClassVars()

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
    /// `RbObject` as well as `RbGateway` without any difference in effect.  This is
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
    /// `RbObject` as well as `RbGateway` without any difference in effect.  This is
    /// purely convenience to put all these getter/setter pairs in the same place and
    /// make construction of `RbFailableAccess` a bit easier.  Best practice probably
    /// to avoid calling the `RbObject` version.)
    @discardableResult
    public func setGlobalVar(_ name: String, newValue: RbObjectConvertible?) throws -> RbObject {
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
    /// - throws: `RbError.rubyException(_:)` if Ruby has a problem.
    ///           `RbError` of some other kind if `name` looks wrong in some way.
    @discardableResult
    public func get(_ name: String) throws -> RbObject {
        if name.isRubyConstantPath {
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
