//
//  RbObject.swift
//  RubyBridge
//
//  Distributed under the MIT license, see LICENSE
//
import RubyBridgeHelpers

/// Wraps a Ruby object
public final class RbObject: RbConstantAccess, RbInstanceAccess {
    private let valueBox: UnsafeMutablePointer<Rbb_value>

    /// Wrap up a Ruby object using the `VALUE` handle
    /// returned by its API, keep the object safe from garbage collection.
    public init(rubyValue: VALUE) {
        valueBox = rbb_value_alloc(rubyValue);
    }

    /// Create another Swift reference to an existing `RbObject`.
    /// The underlying Ruby object will not be GCed until both
    /// `RbObject`s have gone out of scope.
    public init(_ value: RbObject) {
        valueBox = rbb_value_dup(value.valueBox);
    }

    /// Allow the tracked object to be GCed when we go out of scope.
    deinit {
        rbb_value_free(valueBox)
    }

    /// Access the `VALUE` object handle for use with the `CRuby` API.
    ///
    /// If you keep hold of this `VALUE` after the `RbObject` has been
    /// deinitialized then you are responsible for making sure Ruby
    /// does not garbage collect it before you are done with it.
    ///
    /// It works best to keep the `RbObject` around and use this attribute
    /// accessor directly with the API
    public var rubyValue: VALUE {
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
}

// MARK: - Useful convenience initializers

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

// MARK: - String convertible for various debugging APIs

extension RbObject: CustomStringConvertible {
    /// A string representation of the Ruby object.
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
    /// This is just the text from `description`.
    public var customPlaygroundQuickLook: PlaygroundQuickLook {
        return .text(description)
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
