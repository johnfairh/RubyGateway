//
//  RbConversions.swift
//  RubyGateway
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
    /// RubyGateway conforms most of the Swift standard library types
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

// MARK: - Array

/// These methods are available only when the array `Element` type conforms
/// to `RbObjectConvertible`.
extension Array: RbObjectConvertible where Element: RbObjectConvertible {
    /// Try to get a `Array` representation of an `RbObject`.
    ///
    /// Equivalent to `Kernel#Array`: attempts `to_ary` then `to_a`,
    /// if unsupported then creates a one-element array.  Fails if *any* of
    /// the Ruby array elements do not support conversion to the array `Element`
    /// type.
    ///
    /// See `RbError.history` to find out why a conversion failed.
    public init?(_ value: RbObject) {
        self.init()

        let aryValue = value.withRubyValue { rbg_Array_protect($0, nil) }
        if RbException.ignoreAnyPending() {
            return nil
        }

        for i in 0..<rb_array_len(aryValue) {
            let eleValue = rb_ary_entry(aryValue, i)
            guard let element = Element(RbObject(rubyValue: eleValue)) else {
                return nil
            }
            append(element)
        }
    }

    /// Create a Ruby array object for this `Array`.
    public var rubyObject: RbObject {
        guard Ruby.softSetup() else {
            return .nilObject
        }
        return RbObject(rubyValue: map { $0.rubyObject }.withRubyValues { elementValues in
            rb_ary_new_from_values(count, elementValues)
        })
    }
}

// MARK: - ArrayLiteral

extension RbObject: ExpressibleByArrayLiteral {
    /// Creates an `RbObject` from an array literal.
    ///
    /// Although the element type here is `RbObject` you can write things like:
    /// ```swift
    /// let obj: RbObject = [1, 2, 3]
    /// ```
    /// ... because of `RbObject`'s `ExpressibleByIntegerLiteral` conformance
    /// that gets applied recursively.
    public convenience init(arrayLiteral value: RbObject...) {
        self.init(value.rubyObject)
    }
}

// MARK: - Dictionary

/// These methods are available only when both the dictionary `Key` *and* `Value`
/// types conform to `RbObjectConvertible`.
extension Dictionary: RbObjectConvertible where Key: RbObjectConvertible, Value: RbObjectConvertible {
    /// Try to get a `Dictionary` representation of an `RbObject` that is a Ruby hash.
    ///
    /// Based on `Kernel#Hash`: will attempt `to_hash` then `to_h`, has a weird
    /// special case for an empty array, otherwise fails.
    ///
    /// Fails if *any* of the Ruby hash keys or values do do not support conversion
    /// to the corresponding Swift types.
    ///
    /// Fails if more than one of the Ruby hash keys convert to the same Swift value.
    ///
    /// See `RbError.history` to find out why a conversion failed.
    public init?(_ value: RbObject) {
        let hashObj = RbObject(rubyValue: value.withRubyValue { rbg_Hash_protect($0, nil) })
        if RbException.ignoreAnyPending() {
            return nil
        }
        // oh boy
        do {
            var dict: [Key: Value] = [:] // closure cannot capture mutable self
            try hashObj.call("each") { args in
                // Hash#each has way too much magic: undocumentedly it tries to peek at the block
                // arity in the block_given case.  Can't make this work in C so it gets '1'.
                // Then, undocumentedly it parcels K + V up into an array and passes that to us.
                let kvArrayObj = args[0]
                guard let key = Key(kvArrayObj[0]) else {
                    throw RbException(message: "Cannot convert Ruby hash: unconvertible key \(kvArrayObj[0])")
                }
                guard dict[key] == nil else {
                    throw RbException(message: "Cannot convert Ruby hash: duplicate key \(key)")
                }
                guard let value = Value(kvArrayObj[1]) else {
                    throw RbException(message: "Cannot convert Ruby hash: unconvertible value \(kvArrayObj[1])")
                }
                dict[key] = value
                return .nilObject
            }
            self = dict
        } catch {
            return nil
        }
    }

    /// Create a Ruby hash object for this `Dictionary`.
    public var rubyObject: RbObject {
        guard Ruby.softSetup() else {
            return .nilObject
        }
        let hashObj = RbObject(rubyValue: rb_hash_new())
        hashObj.withRubyValue { hashValue in
            forEach { arg in
                arg.key.rubyObject.withRubyValue { keyRubyValue in
                    arg.value.rubyObject.withRubyValue { valueRubyValue in
                        rb_hash_aset(hashValue, keyRubyValue, valueRubyValue)
                    }
                }
            }
        }
        return hashObj
    }
}

// MARK: - DictionaryLiteral

extension RbObject: ExpressibleByDictionaryLiteral {
    /// Creates an `RbObject` from a dictionary literal.
    ///
    /// Although the key and value types here are `RbObject` you can write things like:
    /// ```swift
    /// let obj: RbObject = [1: "fish", 2: "bucket", 3: "wife", 4: "goat"]
    /// ```
    /// ... because of `RbObject`'s `ExpressibleByXxxLiteral` conformance
    /// that gets applied recursively.
    ///
    /// Like a regular `Dictionary` there must be no duplicate keys in the `elements`.
    public convenience init(dictionaryLiteral elements: (RbObject, RbObject)...) {
        self.init(Dictionary(uniqueKeysWithValues: elements))
    }
}

// MARK: - Optional<RbObjectConvertible>

/// This lets you pass literal `nil` in an argument position to a Ruby method
/// and have it transparently turn into Ruby nil.
/// :nodoc:
extension Optional: RbObjectConvertible where Wrapped == RbObjectConvertible {
    public init?(_ value: RbObject) {
        self = .some(value)
    }

    public var rubyObject: RbObject {
        switch self {
        case .some(let w): return w.rubyObject
        case .none: return .nilObject
        }
    }
}
