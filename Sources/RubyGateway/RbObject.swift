//
//  RbObject.swift
//  RubyGateway
//
//  Distributed under the MIT license, see LICENSE
//
import CRuby
import RubyGatewayHelpers

/// A Ruby object.
///
/// All Ruby objects whatever their type or class are represented using this
/// Swift type.
///
/// Use `RbObject.init(ofClass:args:kwArgs:)` to create a new Ruby object of
/// some class:
/// ```swift
/// let myObj = RbObject(ofClass: "MyModule::MyClass", args: ["arg1", 25.3])
/// ```
///
/// See `RbObjectAccess` for ways to call methods, access properties, and find
/// constants from an `RbObject`:
/// ```swift
/// try myObj.set("name", "fred")  // explicit property set
///
/// myObj.name = RbObject("fred")  // dynamic member lookup
///
/// let results = try myObj.call("process", args: ["arg1", 100])
///
/// let answer = try myObj.call("pose", kwArgs: ["questionNumber": 40])
/// ```
///
/// See `RbGateway` and its global instance `Ruby` for access to the Ruby 'top self'
/// object to get started finding constants or calling global functions.
///
/// ## Converting to and from Swift types
///
/// Convert `RbObject`s to Swift types using failable initializers:
/// ```swift
/// let height = Double(myObj)
/// let allHeights = Array<Double>(myObj)
/// let heightDb = Dictionary<String, Double>(myObj)
/// ```
/// Check `RbError.history` to see the cause of failed initializations.
///
/// In the reverse direction, Swift types convert implicitly to `RbObject`
/// when passed as arguments via the `RbObjectConvertible` protocol.
///
/// ## Collection protocols
///
/// The conversion example above converts the entire Ruby array to an independent
/// Swift array.  An alternative is to use `RbObject.collection` which provides
/// a dynamic view onto the Ruby array that supports many Swift collection protocols
/// so you can update a Ruby array like:
/// ```swift
/// myArrayObj.collection.sort(4..<8)
/// ```
///
/// ## Standard library conformances
///
/// `RbObject` conforms to `Hashable`, `Equatable`, and `Comparable` protocols by
/// forwarding to the corresponding Ruby methods.  Beware though that it is easy
/// to trigger Ruby errors here that currently cause RubyGateway to crash.  For
/// example this is poison:
/// ```swift
/// RbObject(3) < RbObject("barney")
/// ```
/// I plan to add more control over what happens here.
///
/// ## Arithmetic operators
///
/// `RbObject` conforms to the `SignedNumeric` protocol by forwarding the regular
/// arithmetic operators to the corresponding Ruby methods.  This means you can
/// write `let a = b + c` where all are `RbObject`s and get a valid value for `a`
/// provided `b` and `c` are any of the Ruby numeric values or any Ruby class that
/// happens to support those operators.
///
/// Again you must take ensure that your Ruby objects support these operators or
/// the program will crash.
public final class RbObject: RbObjectAccess {
    internal let valueBox: UnsafeMutablePointer<Rbg_value>

    /// Wrap up a Ruby object using the its `VALUE` API handle.
    ///
    /// The Ruby object is kept safe from garbage collection until
    /// the Swift object is deallocated.
    ///
    /// This initializer is public to allow use with other parts
    /// of the Ruby API.  It is not normally needed.
    public init(rubyValue: VALUE) {
        valueBox = rbg_value_alloc(rubyValue);
        super.init(getValue: { rubyValue })
    }

    /// Create another Swift reference to an existing `RbObject`.
    ///
    /// The underlying Ruby object will not be garbage-collected until
    /// both `RbObject`s have been deallocated.
    ///
    /// There is still just one Ruby object in the system.  To create
    /// a separate Ruby object do:
    /// ```swift
    /// let myClone = myObject.call("clone")
    /// ```
    public init(_ value: RbObject) {
        valueBox = rbg_value_dup(value.valueBox);
        let rubyValue = valueBox.pointee.value
        super.init(getValue: { rubyValue }, associatedObjects: value.associatedObjects)
    }

    /// Allow the tracked Ruby object to be GCed when we go out of scope.
    deinit {
        rbg_value_free(valueBox)
    }

    /// Access the raw `VALUE` object handle.  Very restricted use because
    /// too hard to use safely outside of the instance!
    /// Use `withRubyValue(...)` instead.
    fileprivate var rubyValue: VALUE {
        return valueBox.pointee.value
    }

    /// Safely access the `VALUE` object handle for use with the Ruby C API.
    ///
    /// There is no direct access to the `VALUE` to prevent accidental use
    /// outside the corresponding `RbObject`'s lifetime.
    /// - parameter call: The closure to pass the object's `VALUE` on to.
    @discardableResult
    public func withRubyValue<T>(call: (VALUE) throws -> T) rethrows -> T {
        return try call(rubyValue)
    }

    /// The Ruby type of this object.  This is a fairly unfriendly enum but
    /// might be useful for debugging.
    public var rubyType: RbType {
        return TYPE(rubyValue)
    }

    /// Is the Ruby object truthy?
    public var isTruthy: Bool {
        return RB_TEST(rubyValue)
    }

    /// Is the Ruby object `nil`?
    ///
    /// If you have Swift `nil` -- that is, you don't have `.some(RbObject)` --
    /// then Ruby failed -- there was probably an exception.  Check `RbError.history`
    /// for a list of recent exceptions.
    ///
    /// If you've got Ruby `nil` -- that is, you've got `RbObject.isNil` -- then
    /// Ruby worked but the call evaluated to [Ruby] `nil`.
    public var isNil: Bool {
        return RB_NIL_P(rubyValue)
    }

    /// An `RbObject` that means `nil` to Ruby.
    public static let nilObject = RbObject(rubyValue: Qnil)

    /// A view onto the Ruby object using Swift collection APIs.
    ///
    /// Intended for use with Ruby arrays, but any object will work provided
    /// it implements `[]`, `[]=`, and `length` like Array does
    ///
    /// This property has a setter to permit syntax like:
    /// ```swift
    /// myObj.collection[3..<12].sort()
    /// ```
    /// The only thing that can be assigned is the object's corresponding
    /// `RbObjectCollection` -- assigning anything else will trap.  Use
    /// `RbObjectCollection.rubyObject` to obtain a collection's underlying Ruby array.
    public var collection: RbObjectCollection {
        get {
            return RbObjectCollection(self)
        }
        set {
            precondition(rubyValue == newValue.rubyObject.rubyValue)
        }
    }
}

// MARK: - In-module utility

extension RbObject {
    /// Check object is a symbol
    func checkIsSymbol() throws {
        guard rubyType == .T_SYMBOL else {
            throw RbError.badType("Expected T_SYMBOL, got \(rubyType.rawValue) \(self)")
        }
    }

    /// Get the 'id' associated with this symbol object
    func withSymbolId<T>(call: (ID) throws -> T) throws -> T {
        try checkIsSymbol()
        return try call(rb_sym2id(rubyValue))
    }

    /// Check object is a proc
    func checkIsProc() throws {
        guard rb_obj_is_proc(rubyValue) == Qtrue else {
            throw RbError.badType("Expected proc, actual type: \(rubyType)")
        }
    }
}

// MARK: - Useful Initializers

extension RbObject {
    /// Create an instance of a given Ruby class.
    ///
    /// Fails (returns `nil`) if anything goes wrong along the way - check `RbError.history` to
    /// find out what failed.
    ///
    /// - parameter ofClass: Name of the class to instantiate.  Can contain `::` to drill
    ///             down into module/etc. scope.
    /// - parameter args: positional arguments to pass to `new` call for the object.  Default none.
    /// - parameter kwArgs: keyword arguments to pass to the `new` call for the object.  Default none.
    public convenience init?(ofClass className: String,
                             args: [RbObjectConvertible?] = [],
                             kwArgs: DictionaryLiteral<String, RbObjectConvertible?> = [:]) {
        guard let obj = try? Ruby.get(className).call("new", args: args, kwArgs: kwArgs) else {
            return nil
        }
        self.init(obj)
    }

    /// Create an instance of a given Ruby class passing a Swift closure as a block.
    ///
    /// Fails (returns `nil`) if anything goes wrong along the way - check `RbError.history` to
    /// find out what failed.
    ///
    /// - parameter ofClass: Name of the class to instantiate.  Can contain `::` to drill
    ///             down into module/etc. scope.
    /// - parameter args: positional arguments to pass to `new` call for the object.  Default none.
    /// - parameter kwArgs: keyword arguments to pass to the `new` call for the object.  Default none.
    /// - parameter retainBlock: Should `blockCall` be retained by the object?  Default `false`.  Set
    ///             `true` if Ruby uses the block after this call.  For example creating a Proc object
    ///             using `Proc#new`.
    /// - parameter blockCall: Swift code to pass as a block to the method.
    public convenience init?(ofClass className: String,
                             args: [RbObjectConvertible?] = [],
                             kwArgs: DictionaryLiteral<String, RbObjectConvertible?> = [:],
                             retainBlock: Bool = false,
                             blockCall: @escaping RbBlockCallback) {
        let retention: RbBlockRetention = retainBlock ? .returned : .none
        guard let obj = try? Ruby.get(className).call("new",
                                                      args: args, kwArgs: kwArgs,
                                                      blockRetention: retention,
                                                      blockCall: blockCall) else {
            return nil
        }
        self.init(obj)
    }

    /// Create a Ruby Proc object from a Swift closure.
    ///
    /// - parameter blockCall: The callback for the proc.
    /// - warning: You must not allow this `RbObject` to be deallocated before Ruby has
    ///            finished with the block, or the process will crash when Ruby calls it.
    public convenience init(blockCall: @escaping RbBlockCallback) {
        if let obj = try? Ruby.get("Proc").call("new", blockRetention: .returned, blockCall: blockCall) {
            self.init(obj)
        } else {
            self.init(rubyValue: Qnil)
        }
    }
}

// MARK: - String Convertible

extension RbObject: CustomStringConvertible,
                    CustomDebugStringConvertible,
                    CustomPlaygroundDisplayConvertible {
    /// A string representation of the Ruby object.
    ///
    /// This is the same as `String(rbObject)` which is approximately `Kernel#String`.
    public var description: String {
        guard let str = String(self) else {
            return "[Indescribable]"
        }
        return str
    }

    /// A developer-appropriate string representation of the Ruby object.
    ///
    /// This is the result of `inspect` with a fallback to `description`.
    public var debugDescription: String {
        if let value = try? RbVM.doProtect { () -> VALUE in
               rbg_inspect_protect(rubyValue, nil)
           },
           let str = String(RbObject(rubyValue: value)) {
            return str
        }
        return description
    }

    /// The text from `description`.
    public var playgroundDescription: Any {
        return description
    }
}

// MARK: - Standard Library Conformances

extension RbObject: Hashable, Equatable, Comparable {
    /// The hash value for the Ruby object.
    ///
    /// Calls the Ruby `hash` method.
    /// - note: Crashes the process (`fatalError`) if the object does not support `hash`
    ///   or if the `hash` call returns something that can't be converted to `Int`.
    public var hashValue: Int {
        // Have to do this to avoid dictionary literal type stuff causing crashes when setup has failed.
        guard Ruby.softSetup() else {
            return 0
        }
        // not super happy about this - could we instead call hash just once, cache
        // result + use some arbitrary value on failure?
        do {
            let hashObj = try call("hash")
            guard let hash = Int(hashObj) else {
                fatalError("Hash value for \(self) not numeric: \(hashObj)")
            }
            return hash
        } catch {
            fatalError("Calling 'hash' on \(self) failed: \(error)")
        }
    }

    /// Returns a Boolean value indicating whether two values are equal.
    ///
    /// Calls the Ruby `==` method of the `lhs` passing `rhs` as the parameter.
    /// - note: Crashes the process (`fatalError`) if the call to `==` goes wrong.
    /// - returns: Whether the objects are the same under `==`.
    public static func ==(lhs: RbObject, rhs: RbObject) -> Bool {
        do {
            let result = try lhs.call("==", args: [rhs])
            return result.isTruthy
        } catch {
            // again could just say 'false' here - but worried about inconsistent
            // behaviour over time.  Maybe dumb to worry given actively hostile
            // Ruby code could just do that in-band.
            fatalError("Calling '==' on \(lhs) with \(rhs) failed: \(error)")
        }
    }

    /// Returns a Boolean value indicating whether the value of the first
    /// argument is less than that of the second argument.
    ///
    /// Calls the Ruby `<` method of `lhs` passing `rhs` as the parameter.
    /// - note: Crashes the process (`fatalError`) if the call to `<` goes wrong.
    public static func <(lhs: RbObject, rhs: RbObject) -> Bool {
        do {
            let result = try lhs.call("<", args: [rhs])
            return result.isTruthy
        } catch {
            // once more could just say 'false' here...
            fatalError("Calling '<' on \(lhs) with \(rhs) failed: \(error)")
        }
    }
}

// MARK: - Array<RbObject> helper

extension Array where Element == RbObject {
    /// Access the `VALUE`s associated with an array of `RbObject`s.
    /// Prevents Swift from dealloc'ing the objects for the duration of the call.
    /// - parameter call: Closure to pass the `VALUE`s on to.
    internal func withRubyValues<T>(call: ([VALUE]) throws -> T) rethrows -> T {
        return try call(map { $0.rubyValue })
    }
}

