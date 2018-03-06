//
//  RbObject.swift
//  RubyBridge
//
//  Distributed under the MIT license, see LICENSE
//
import RubyBridgeHelpers

/// A Ruby object.
///
/// All Ruby objects whatever their type or class are represented using this
/// Swift type.
///
/// Use `RbObject.init(ofClass:args:kwArgs)` to create a new Ruby object of
/// some class:
/// ```swift
/// let myObj = RbObject(ofClass: "MyModule::MyClass", args: ["arg1", 25.3])
/// ```
///
/// See `RbObjectAccess` for ways to call methods, access properties, and find
/// constants from an `RbObject`:
/// ```swift
/// try myObj.set("name", "fred")
///
/// let results = try myObj.call("process", args: ["arg1", 100])
/// ```
///
/// Or in Swift 5 dynamic-member style:
/// ```swift
/// myObj.name = "fred"
///
/// let results = myObj.process(arg1, 100)
/// ```
///
/// See `RbBridge` and its global instance `Ruby` for access to the Ruby 'top self'
/// object to get started finding constants or calling global functions.
///
/// ## Converting to and from Swift types
///
/// Convert `RbObject`s to Swift types using failable initializers:
/// ```swift
/// let height = Double(myObj)
/// let heightDb = Dictionary<String, Double>(myObj) // one day!
/// ```
/// Check `RbError.history` to see the cause of failed initializations.
///
/// In the reverse direction, Swift types convert implicitly to `RbObject`
/// when passed as arguments via the `RbObjectConvertible` protocol.
///
/// ## Standard library conformances
///
/// `RbObject` conforms to `Hashable`, `Equatable`, and `Comparable` protocols by
/// forwarding to the corresponding Ruby methods.  Beware though that it is easy
/// to trigger Ruby errors here that currently cause `RubyBridge` to crash.  For
/// example this is poison:
/// ```swift
/// `RbObject(3) < RbObject("barney")`
/// ```
/// I plan to add more control over what happens here.
///
/// + arithmetic
public final class RbObject: RbObjectAccess {
    private let valueBox: UnsafeMutablePointer<Rbb_value>

    /// Wrap up a Ruby object using the its `VALUE` API handle.
    ///
    /// The Ruby object is kept safe from garbage collection until
    /// the Swift object is deallocated.
    ///
    /// This initializer is public to let you use it with other parts
    /// of the Ruby API, shouldn't normally be needed.
    public init(rubyValue: VALUE) {
        valueBox = rbb_value_alloc(rubyValue);
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
        valueBox = rbb_value_dup(value.valueBox);
        let rubyValue = valueBox.pointee.value
        super.init(getValue: { rubyValue })
    }

    /// Allow the tracked object to be GCed when we go out of scope.
    deinit {
        rbb_value_free(valueBox)
    }

    /// Access the raw `VALUE` object handle.  Very restricted use because
    /// too hard to use safely outside of the instance!
    /// Use `withRubyValue(...)` instead.
    fileprivate var rubyValue: VALUE {
        return valueBox.pointee.value
    }

    /// Temp access to the handle
    internal var unsafeRubyValue: VALUE {
        return rubyValue
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
}

// MARK: - Useful initializers

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
                             args: [RbObjectConvertible] = [],
                             kwArgs: [(String, RbObjectConvertible)] = []) {
        guard let obj = try? Ruby.get(className).call("new", args: args, kwArgs: kwArgs) else {
            return nil
        }
        self.init(obj)
    }

    /// Create a Ruby `Symbol` object from a string.  Symbols are written `:name` in Ruby.
    ///
    /// - parameter symbolName: Name of the symbol.
    public convenience init(symbolName: String) {
        guard Ruby.softSetup(),
              let id = try? Ruby.getID(for: symbolName) else {
            self.init(rubyValue: Qnil)
            return
        }
        self.init(rubyValue: rb_id2sym(id))
    }
}

// MARK: - String convertible

extension RbObject: CustomStringConvertible {
    /// A string representation of the Ruby object.
    ///
    /// This is the same as `String(rbObject)` which is approximately `Kernel#String`.
    public var description: String {
        guard let str = String(self) else {
            return "[Indescribable]"
        }
        return str
    }
}

extension RbObject: CustomDebugStringConvertible {
    /// A developer-appropriate string representation of the Ruby object.
    ///
    /// This is the result of `inspect` with a fallback to `description`.
    public var debugDescription: String {
        if let value = try? RbVM.doProtect { () -> VALUE in
               rbb_inspect_protect(rubyValue, nil)
           },
           let str = String(RbObject(rubyValue: value)) {
            return str
        }
        return description
    }
}

extension RbObject: CustomPlaygroundQuickLookable {
    /// Something to display in Playgrounds right-hand bar.
    ///
    /// This is just the text from `description`.
    public var customPlaygroundQuickLook: PlaygroundQuickLook {
        return .text(description)
    }
}

// MARK: - Hashable etc.

extension RbObject: Hashable, Equatable, Comparable {
    /// The hash value for the Ruby object.
    ///
    /// Calls the Ruby `hash` method.
    /// - note: Crashes the process (`fatalError`) if the object does not support `hash`
    ///   or if the `hash` call returns something that can't be converted to `Int`.
    public var hashValue: Int {
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
