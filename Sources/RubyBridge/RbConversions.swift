//
//  RbConversions.swift
//  RubyBridge
//
//  Distributed under the MIT license, see LICENSE
//
//  Chris Lattner's Python DML playground provided invaluable guidance
//  through the tangle of conversion directions and functions.
//

import CRuby
import Foundation
import RubyBridgeHelpers

/// Protocol adopted by types that can be converted to and from RbObjects.
public protocol RbObjectConvertible {
    /// Try to create an instance of this type from the Ruby object.
    /// Returns `nil` if the object cannot be converted, for example a
    /// complete type mismatch, or a numeric type that won't fit.
    init?(_ value: RbObject)

    /// Get a Ruby version of this type.
    var rubyObject: RbObject { get }
}

/// Anything -> RbObject
extension RbObject {
    /// Explicitly create an RbObject from something else.
    public convenience init(_ value: RbObjectConvertible) {
        self.init(value.rubyObject)
    }
}

/// RbObject <-> RbObject
extension RbObject: RbObjectConvertible {
    /// Create another Swift reference to an existing `RbObject`.
    /// The underlying Ruby object will not be GCed until both
    /// `RbObject`s have gone out of scope.
    public convenience init(_ value: RbObject) {
        self.init(copy: value)
    }

    /// Returns `self`, the `RbObject`.
    ///
    /// :nodoc:
    public var rubyObject: RbObject { return self }
    // Quick sanity check here: RbObject is a ref type so this `return self` is OK,
    // it returns a second ref-counted ptr to the single `RbObj` which has a single
    // `Rbb_val`.  There is no aliasing of `Rbb_val` ownership.
    // WBN to not see this property though.
}

// MARK: - String

extension String: RbObjectConvertible {
    /// Try to get a `String` representation of an `RbObject`.
    ///
    /// This is equivalent to calling `to_str` on the Ruby object
    /// which means that it succeeds only for objects that are
    /// actually strings.
    ///
    /// See `RbException.history` to find out why a conversion failed.
    ///
    /// If you want the stringy version of an object then options are:
    /// ```swift
    /// let str = rbObject.call("to_s")
    /// let str = rbObject.to_s           // Swift 5
    /// let str = "\(rbObject)"           // calls to_s
    /// ```
    public init?(_ value: RbObject) {
        var status = Int32(0)
        let stringVal = rbb_string_value_protect(value.rubyValue, &status)
        guard status == 0 else {
            let _ = rb_errinfo()
            rb_set_errinfo(Qnil)
            // TODO: RbException
            return nil
        }

        let rubyLength = RSTRING_LEN(stringVal)
        let rubyPtr = RSTRING_PTR(stringVal)
        let rubyData = Data(bytes: rubyPtr, count: rubyLength)

        self.init(data: rubyData, encoding: .utf8)
    }

    /// Create a Ruby object for the string.
    public var rubyObject: RbObject {
        guard Ruby.softSetup() else {
            return RbObject(rubyValue: Qnil)
        }
        return RbObject(rubyValue: withCString { rb_utf8_str_new($0, utf8.count) })
    }
}

extension RbObject: ExpressibleByStringLiteral {
    /// Creates an `RbObject` from a string literal
    public convenience init(stringLiteral value: String) {
        self.init(value.rubyObject)
    }
}

// MARK: - Boolean

extension Bool: RbObjectConvertible {
    /// Try to get a `Bool` representation of an `RbObject`.
    ///
    /// This is a strict conversion that fails if the Ruby object is not
    /// an actual true/false.  Use `RbObject.isTruthy` to decide whether
    /// an `RbObject` represents a truthy value to Ruby.
    public init?(_ value: RbObject) {
        switch value.rubyValue {
        case Qtrue: self = true
        case Qfalse: self = false
        default: return nil
        }
    }

    /// Create a Ruby object for the bool.
    public var rubyObject: RbObject {
        return RbObject(rubyValue: self ? Qtrue : Qfalse)
    }
}

extension RbObject: ExpressibleByBooleanLiteral {
    /// Creates an `RbObject` from a boolean literal
    public convenience init(booleanLiteral value: Bool) {
        self.init(value.rubyObject)
    }
}

// MARK: - Nil

extension RbObject: ExpressibleByNilLiteral {
    /// Creates an `RbObject` for `nil`
    public convenience init(nilLiteral: ()) {
        self.init(rubyValue: Qnil)
    }
}

// MARK: - Unsigned Integer

extension UInt: RbObjectConvertible {
    /// Try to get an unsigned integer representation of an `RbObject`.
    ///
    /// It fails if the Ruby value:
    /// 1. Is numeric and negative; or
    /// 2. Is numeric, positive, and does not fit into the Swift type; or
    /// 3. Cannot be made into a suitable numeric via `to_int`.
    ///
    /// See `RbException.history` to find out why a conversion failed.
    ///
    /// If the Ruby value is floating point then the integer part is returned.
    public init?(_ value: RbObject) {
        var status = Int32(0)
        self = rbb_num2ulong_protect(value.rubyValue, &status)
        guard status == 0 else {
            let _ = rb_errinfo()
            rb_set_errinfo(Qnil)
            // TODO: RbException
            return nil
        }
    }

    /// Create a Ruby object for the number.
    public var rubyObject: RbObject {
        guard Ruby.softSetup() else {
            return RbObject(rubyValue: Qnil)
        }
        return RbObject(rubyValue: RB_ULONG2NUM(self))
    }
}

// MARK: - Signed Integer

extension Int: RbObjectConvertible {
    /// Try to get an signed integer representation of an `RbObject`.
    ///
    /// It fails if the Ruby value:
    /// 1. Is numeric and does not fit into the Swift type; or
    /// 2. Cannot be made into a suitable numeric via `to_int`.
    ///
    /// See `RbException.history` to find out why a conversion failed.
    ///
    /// If the Ruby value is floating point then the integer part is returned.
    public init?(_ value: RbObject) {
        var status = Int32(0)
        self = rbb_num2long_protect(value.rubyValue, &status)
        guard status == 0 else {
            let _ = rb_errinfo()
            rb_set_errinfo(Qnil)
            // TODO: RbException
            return nil
        }
    }

    /// Create a Ruby object for the number.
    public var rubyObject: RbObject {
        guard Ruby.softSetup() else {
            return RbObject(rubyValue: Qnil)
        }
        return RbObject(rubyValue: RB_LONG2NUM(self))
    }
}

extension RbObject: ExpressibleByIntegerLiteral {
    public convenience init(integerLiteral value: Int) {
        self.init(value.rubyObject)
    }
}

// MARK: - Double

extension Double: RbObjectConvertible {
    /// Try to get a `Double` floating-point representation of an `RbObject`.
    ///
    /// It fails if the Ruby value:
    /// 1. Is numeric and does not fit into the Swift type; or
    /// 2. Cannot be made into a suitable numeric via `to_f`.
    ///
    /// See `RbException.history` to find out why a conversion failed.
    ///
    /// If the Ruby value is floating point then the integer part is returned.
    public init?(_ value: RbObject) {
        var status = Int32(0)
        self = rbb_num2double_protect(value.rubyValue, &status)
        guard status == 0 else {
            let _ = rb_errinfo()
            rb_set_errinfo(Qnil)
            // TODO: RbException
            return nil
        }
    }

    /// Create a Ruby object for the number.
    public var rubyObject: RbObject {
        guard Ruby.softSetup() else {
            return RbObject(rubyValue: Qnil)
        }
        return RbObject(rubyValue: DBL2NUM(self))
    }
}

extension RbObject: ExpressibleByFloatLiteral {
    public convenience init(floatLiteral value: Double) {
        self.init(value.rubyObject)
    }
}
