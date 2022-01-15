//
//  RbConversions.swift
//  RubyGateway
//
//  Distributed under the MIT license, see LICENSE
//
//  Chris Lattner's Python DML playground provided invaluable guidance
//  through the tangle of conversion directions and functions.
//
@_implementationOnly import CRuby
@_implementationOnly import RubyGatewayHelpers
import Foundation

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

extension RbObject {
    /// Convert an RbObject to some Swift type.
    ///
    /// This is a convenience wrapper around optional conversion for cases where
    /// the Swift type can be inferred.  See `convert(to:)` to explicitly specify
    /// the desired type.
    ///
    /// - throws: `RbError.badType(...)` if the conversion fails.  There may be a more
    ///            detailed exception inside `RbError.history`.
    public func convert<T: RbObjectConvertible>() throws -> T {
        guard let value = T(self) else {
            throw RbError.badType("Cannot convert \(self) to Swift type \(T.self)")
        }
        return value
    }

    /// Convert an RbObject to some Swift type.
    ///
    /// This is a convenience wrapper around optional conversion.  See `convert()`
    /// for when the desired type can be inferred by the compiler.
    ///
    /// - throws: `RbError.badType(...)` if the conversion fails.  There may be a more
    ///            detailed exception inside `RbError.history`.
    public func convert<T: RbObjectConvertible>(to type: T.Type) throws -> T {
        guard let value = T(self) else {
            throw RbError.badType("Cannot convert \(self) to Swift type \(T.self)")
        }
        return value
    }
}

// MARK: - String

extension String: RbObjectConvertible {
    /// Try to get a `String` representation of an `RbObject`.
    ///
    /// This calls Ruby `Kernel#String` on the object, which tries
    /// `to_str` followed by `to_s`.
    ///
    /// See `RbError.history` to find out why a conversion failed.
    public init?(_ object: RbObject) {
        do {
            guard let string = try Self.rubyToString(object) else {
                return nil
            }
            self = string
        } catch {
            // Workaround for odd Ruby 3.1 issue:
            //
            // In Ruby 3.1, calling `to_s` on a `NameError` from this environment
            // causes an exception: "TypeError: wrong argument type nil (expected method)"
            // ...which is a bit baffling.  It works fine in IRB.
            //
            // Pragmatically going to ignore the root cause here, just catch the
            // situation and retrieve the actual text -- this `original_message` method
            // is from `DidYouMean::Correctable` which suspiciously overrides the `to_s`
            // that doesn't work.
            guard let originalMessage = try? object.call("original_message"),
                  let messageText = try? Self.rubyToString(originalMessage) else {
                return nil
            }
            self = messageText
        }
    }

    /// Internal helper to do the Ruby conversion.
    /// Throws an error if the Ruby `to_s` throws an error.
    /// Returns `nil` if the Ruby string data can't be interpreted as UTF-8.
    private static func rubyToString(_ object: RbObject) throws -> String? {
        let stringVal = try object.withRubyValue { objValue in
            try RbVM.doProtect { tag in
                rbg_String_protect(objValue, &tag)
            }
        }

        let rubyLength = rbg_RSTRING_LEN(stringVal)
        let rubyPtr = rbg_RSTRING_PTR(stringVal)
        let rubyData = Data(bytes: rubyPtr, count: rubyLength)

        return String(data: rubyData, encoding: .utf8)
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
    public init?(_ object: RbObject) {
        do {
            self = try object.withRubyValue { objValue in
                try RbVM.doProtect { tag in
                    rbg_obj2ulong_protect(objValue, &tag)
                }
            }
        } catch {
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
    public init?(_ object: RbObject) {
        do {
            self = try object.withRubyValue { objValue in
                try RbVM.doProtect { tag in
                    rbg_obj2long_protect(objValue, &tag)
                }
            }
        } catch {
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
    public init?(_ object: RbObject) {
        do {
            self = try object.withRubyValue { objValue in
                try RbVM.doProtect { tag in
                    rbg_obj2double_protect(objValue, &tag)
                }
            }
        } catch {
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
    public init?(_ object: RbObject) {
        self.init()

        do {
            let aryValue = try object.withRubyValue { objValue in
                try RbVM.doProtect { tag in
                    rbg_Array_protect(objValue, &tag)
                }
            }
            for i in 0..<rb_array_len(aryValue) {
                let eleValue = rb_ary_entry(aryValue, i)
                guard let element = Element(RbObject(rubyValue: eleValue)) else {
                    return nil
                }
                append(element)
            }
        } catch {
            return nil
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

// MARK: - ArraySlice

/// These methods are available only when the array slice `Element` type
/// conforms to `RbObjectConvertible`.
extension ArraySlice: RbObjectConvertible where Element: RbObjectConvertible {
    /// No sense in converting :nodoc:
    public init?(_ value: RbObject) {
        return nil
    }

    /// Create a Ruby array object for this `ArraySlice`.  All the sliceness
    /// is lost by this conversion, there's no ongoing relation between the Swift
    /// and Ruby types.
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
    public init?(_ object: RbObject) {
        do {
            let hashObj = RbObject(rubyValue: try object.withRubyValue { objValue in
                try RbVM.doProtect { tag in
                    rbg_Hash_protect(objValue, &tag)
                }
            })
            // oh boy
            var dict: [Key: Value] = [:] // closure cannot capture mutable self
            try hashObj.call("each") { args in
                // Hash#each has way too much magic: undocumentedly it tries to peek at the block
                // arity in the block_given case.  Can't make this work in C so it gets '-1'.
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
    ///
    /// If multiple Swift `Key`s convert to the same Ruby Key objects
    /// then the conversion fails and the routine returns `RbObject.nilObject`.
    /// This is quite a tough condition to hit without adding additional
    /// `RbObjectConvertible` conformances.
    public var rubyObject: RbObject {
        guard Ruby.softSetup() else {
            return .nilObject
        }
        let hashObj = RbObject(rubyValue: rb_hash_new())
        do {
            try forEach { arg in
                let newRbKey = arg.key.rubyObject
                guard !(try hashObj.call("key?", args: [newRbKey]).isTruthy) else {
                    throw RbException(message: "Cannot convert Swift dictionary, duplicate key \(newRbKey)")
                }
                try hashObj.call("store", args: [newRbKey, arg.value])
            }
        } catch {
            return .nilObject
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

// MARK: - Range<RbObjectConvertible>

/// Helper to extract range parameters from something that quacks
/// like a Ruby Range.
private func decodeRange<T>(_ object: RbObject, halfOpen: Bool) -> (T, T)? where T: RbObjectConvertible & Comparable {
    guard let lowerObj = try? object.get("begin"),
          let upperObj = try? object.get("end"),
          let halfOpenObj = try? object.get("exclude_end?"),
          halfOpenObj.isTruthy == halfOpen else {
              return nil
    }
    // Check Swift conversion
    guard let lower = T(lowerObj),
          let upper = T(upperObj),
          lower < upper else {
              return nil
    }
    return (lower, upper)
}

/// Helper to create a Ruby Range from Swift types.
private func makeRange<T>(lower: T, upper: T, halfOpen: Bool) -> RbObject where T: RbObjectConvertible {
    return RbObject(ofClass: "Range", args: [lower, upper, halfOpen]) ?? .nilObject
}

// One day Swift will catch up with C++ and let me write this as a single generic...

/// These methods are available only when the range `Bound` type conforms to
/// `RbObjectConvertible`.
extension Range: RbObjectConvertible where Bound: RbObjectConvertible {
    /// Try to get a `Range` from a Ruby range object.
    ///
    /// Fails if the Ruby object isn't a half-open range.  Fails if the Ruby range
    /// endpoints cannot be converted to the `Bound` type.
    public init?(_ value: RbObject) {
        guard let bounds: (Bound, Bound) = decodeRange(value, halfOpen: true) else {
            return nil
        }
        self.init(uncheckedBounds: bounds)
    }

    /// A Ruby object for the range.
    public var rubyObject: RbObject {
        return makeRange(lower: lowerBound, upper: upperBound, halfOpen: true)
    }
}

// MARK: - ClosedRange<RbObjectConvertible>

/// These methods are available only when the range `Bound` type conforms to
/// `RbObjectConvertible`.
extension ClosedRange: RbObjectConvertible where Bound: RbObjectConvertible {
    /// Try to get a `ClosedRange` from a Ruby range object.
    ///
    /// Fails if the Ruby object isn't a closed range.  Fails if the Ruby range
    /// endpoints cannot be converted to the `Bound` type.
    public init?(_ value: RbObject) {
        guard let bounds: (Bound, Bound) = decodeRange(value, halfOpen: false) else {
            return nil
        }
        self.init(uncheckedBounds: bounds)
    }

    /// A Ruby object for the range.
    public var rubyObject: RbObject {
        return makeRange(lower: lowerBound, upper: upperBound, halfOpen: false)
    }
}

// MARK: - Set

/// These methods are available only when the set `Element` type conforms
/// to `RbObjectConvertible`.
extension Set: RbObjectConvertible where Element: RbObjectConvertible {
    /// Try to get a `Set` representation of an `RbObject`.
    ///
    /// Calls `to_set` on the object and then converts each element.
    ///
    /// Fails if *any* of the elements do not support conversion to the set
    /// `Element` type.
    ///
    /// Fails if any of the Ruby set elements convert to the same Swift
    /// element, ie. if the Swift set would have a smaller cardinality
    /// than the Ruby set.
    ///
    /// See `RbError.history` to find out why a conversion failed.
    public init?(_ value: RbObject) {
        self.init()
        do {
            let setObj = try value.call("to_set")
            var newSet = Set<Element>() // closure cannot capture mutable self
            try setObj.call("each") { args in
                guard let ele = Element(args[0]) else {
                    throw RbException(message: "Cannot convert Ruby set: unconvertible ele \(args[0])")
                }
                guard !newSet.contains(ele) else {
                    throw RbException(message: "Cannot convert Ruby set: duplicate ele \(ele)")
                }
                newSet.insert(ele)
                return .nilObject
            }
            self = newSet
        } catch {
            return nil
        }
    }

    /// Create a Ruby set object for this `Set`.
    ///
    /// If multiple Swift `Element`s convert to the same Ruby Key objects
    /// then the conversion fails and the routine returns `RbObject.nilObject`.
    /// This is quite a tough condition to hit without adding additional
    /// `RbObjectConvertible` conformances.
    public var rubyObject: RbObject {
        guard Ruby.softSetup(),
            let set = RbObject(ofClass: "Set") else {
            return .nilObject
        }
        do {
            try forEach { ele in
                let dupTest = try set.call("add?", args: [ele.rubyObject])
                if dupTest == .nilObject {
                    throw RbException(message: "Cannot convert Swift set: duplicate ele \(ele)")
                }
            }
        } catch {
            return .nilObject
        }
        return set
    }
}
