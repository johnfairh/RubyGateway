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
import RubyGatewayHelpers

/// Protocol adopted by types that can be converted to and from `RbObject`s.
public protocol RbObjectConvertible {
    /// Try to create an instance of this type from the Ruby object.
    ///
    /// Returns `nil` if the object cannot be converted, for example a
    /// complete type mismatch or a numeric type that won't fit.
    init?(_ value: RbObject)

    /// A fresh Ruby object matching the current state of the Swift object.
    ///
    /// If Ruby is not working (VM setup failure) then the vended object is
    /// some invalid value.  The VM setup failure is reported at the point
    /// the object is used.
    var rubyObject: RbObject { get }
}

// MARK: - RbObjectConvertible

extension RbObject {
    /// Create an `RbObject` from a Swift type.
    ///
    /// RubyBridge conforms most of the Swift standard library types
    /// to `RbObjectConvertible`.
    public convenience init(_ value: RbObjectConvertible) {
        self.init(value.rubyObject)
    }
}

/// RbObject <-> RbObject
extension RbObject: RbObjectConvertible {
    /// Returns `self`, the `RbObject`.
    ///
    /// :nodoc:
    public var rubyObject: RbObject { return self }
    // Quick sanity check here: RbObject is a ref type so this `return self` is OK,
    // it returns a second ref-counted ptr to the single `RbObj` which has a single
    // `Rbb_val`.  There is no aliasing of `Rbb_val` ownership.
    //
    // Although semantics of `rubyObject` suggest we need to provide clone here.
    // TBD.  Perhaps need two accessors with default implementation.
}

// MARK: - String

extension String: RbObjectConvertible {
    /// Try to get a `String` representation of an `RbObject`.
    ///
    /// This calls Ruby `Kernel#String` on the object, which tries
    /// `to_str` followed by `to_s`.
    ///
    /// See `RbError.history` to find out why a conversion failed.
    public init?(_ value: RbObject) {
        let stringVal = value.withRubyValue { rbg_String_protect($0, nil) }
        if RbException.ignoreAnyPending() {
            return nil
        }

        let rubyLength = RSTRING_LEN(stringVal)
        let rubyPtr = RSTRING_PTR(stringVal)
        let rubyData = Data(bytes: rubyPtr, count: rubyLength)

        self.init(data: rubyData, encoding: .utf8)
    }

    /// A Ruby object for the string.
    public var rubyObject: RbObject {
        guard Ruby.softSetup() else {
            return .nilObject
        }
        return RbObject(rubyValue: withCString { rb_utf8_str_new($0, utf8.count) })
    }
}

// MARK: - StringLiteral

extension RbObject: ExpressibleByStringLiteral {
    /// Creates an `RbObject` from a string literal.
    public convenience init(stringLiteral value: String) {
        self.init(value.rubyObject)
    }
}

// MARK: - Boolean

extension Bool: RbObjectConvertible {
    /// Try to get a `Bool` representation of an `RbObject`.
    ///
    /// This is a loose, potentially lossy conversion that reflects
    /// the truthiness of the Ruby object.
    public init?(_ value: RbObject) {
        guard value.rubyType != .T_UNDEF else {
            return nil
        }
        self = value.isTruthy
    }

    /// A Ruby object for the boolean value.
    public var rubyObject: RbObject {
        return RbObject(rubyValue: self ? Qtrue : Qfalse)
    }
}

// MARK: - BooleanLiteral

extension RbObject: ExpressibleByBooleanLiteral {
    /// Creates an `RbObject` from a boolean literal.
    public convenience init(booleanLiteral value: Bool) {
        self.init(value.rubyObject)
    }
}

// MARK: - Unsigned Integer

extension UInt: RbObjectConvertible {
    /// Try to get an unsigned integer representation of an `RbObject`.
    ///
    /// It fails if the Ruby value:
    /// 1. Is numeric and negative; or
    /// 2. Is numeric, positive, and does not fit into the Swift type; or
    /// 3. Cannot be made into a suitable numeric via `to_int` or `to_i`.
    ///
    /// See `RbError.history` to find out why a conversion failed.
    ///
    /// If the Ruby value is floating-point then the integer part is used.
    public init?(_ value: RbObject) {
        self = value.withRubyValue { rbg_obj2ulong_protect($0, nil) }
        if RbException.ignoreAnyPending() {
            return nil
        }
    }

    /// A Ruby object for the number.
    public var rubyObject: RbObject {
        guard Ruby.softSetup() else {
            return .nilObject
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
    /// 2. Cannot be made into a suitable numeric via `to_int` or `to_i`.
    ///
    /// See `RbError.history` to find out why a conversion failed.
    ///
    /// If the Ruby value is floating-point then the integer part is used.
    public init?(_ value: RbObject) {
        self = value.withRubyValue { rbg_obj2long_protect($0, nil) }
        if RbException.ignoreAnyPending() {
            return nil
        }
    }

    /// A Ruby object for the number.
    public var rubyObject: RbObject {
        guard Ruby.softSetup() else {
            return .nilObject
        }
        return RbObject(rubyValue: RB_LONG2NUM(self))
    }
}

// MARK: - IntegerLiteral

extension RbObject: ExpressibleByIntegerLiteral {
    /// Creates an `RbObject` from an integer literal.
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
    /// See `RbError.history` to find out why a conversion failed.
    ///
    /// Flavors of NaN are not preserved across the Ruby<->Swift interface.
    public init?(_ value: RbObject) {
        self = value.withRubyValue { rbg_obj2double_protect($0, nil) }
        if RbException.ignoreAnyPending() {
            return nil
        }
    }

    /// A Ruby object for the number.
    public var rubyObject: RbObject {
        guard Ruby.softSetup() else {
            return .nilObject
        }
        return RbObject(rubyValue: DBL2NUM(self))
    }
}

// MARK: - FloatLiteral

extension RbObject: ExpressibleByFloatLiteral {
    /// Creates an `RbObject` from a floating-point literal.
    public convenience init(floatLiteral value: Double) {
        self.init(value.rubyObject)
    }
}

// MARK: - Dictionary
//extension Dictionary: RbObjectConvertible where Key: RbObjectConvertible, Value: RbObjectConvertible {
//    /// Try to get a `Dictionary` representation of an `RbObject` that is a Ruby hash.
//    ///
//    /// It fails if the Ruby value is not a hash.
//    ///
//    /// See `RbError.history` to find out why a conversion failed.
//    public init?(_ value: RbObject) {
//        return nil
//    }
//
//    /// Create a Ruby hash object for the dictionary.
//    public var rubyObject: RbObject {
//        guard Ruby.softSetup() else {
//            return RbObject(rubyValue: Qnil)
//        }
//        return dictToRubyObj(self)
//    }
//}

//
//func dictToRubyObj<K>(dict: [K: RbObjectConvertible]) -> RbObject where K: RbObjectConvertible {
//    let hashObj = RbObject(rubyValue: rb_hash_new())
//    dict.forEach { key, value in
//        key.rubyObject.withRubyValue { keyRubyValue in
//            value.rubyObject.withRubyValue { valueRubyValue in
//                rb_hash_aset(hashObj.rubyValue, keyRubyValue, valueRubyValue)
//            }
//        }
//    }
//    return hashObj
//}
