//
//  RbOperators.swift
//  RubyBridge
//
//  Distributed under the MIT license, see LICENSE
//

// This file provides conformances and so on to let users treat `RbObject`s as
// number-like things, forwarding on to Ruby methods for +-*/ and enabling
// various standard library etc. usages of `Numeric` and `SignedNumeric`.
//
// I'm not certain this is useful or wise, mostly because the underlying Ruby
// objects could do anything.  But, mostly it will not and the convenience of
// working directly is probably worth it.
//
// More concerning is the lack of error handling - need to refactor in future
// similar to `Hashable` etc. to enable less shakey policy.

// MARK: - Numeric operators

extension RbObject: SignedNumeric {

    public static func -(lhs: RbObject, rhs: RbObject) -> RbObject {
        do {
            return try lhs.call("-", args: [rhs])
        } catch {
            fatalError("Calling '-' on \(lhs) with \(rhs) failed: \(error)")
        }
    }

    public static func +(lhs: RbObject, rhs: RbObject) -> RbObject {
        do {
            return try lhs.call("+", args: [rhs])
        } catch {
            fatalError("Calling '+' on \(lhs) with \(rhs) failed: \(error)")
        }
    }

    public static func *(lhs: RbObject, rhs: RbObject) -> RbObject {
        do {
            return try lhs.call("*", args: [rhs])
        } catch {
            fatalError("Calling '*' on \(lhs) with \(rhs) failed: \(error)")
        }
    }

    // OK why do these not have default implementations?

    public static func +=(lhs: inout RbObject, rhs: RbObject) {
        lhs = lhs + rhs
    }

    public static func -=(lhs: inout RbObject, rhs: RbObject) {
        lhs = lhs - rhs
    }

    public static func *=(lhs: inout RbObject, rhs: RbObject) {
        lhs = lhs * rhs
    }

    /// Create a Ruby object from some type conforming to `BinaryInteger`
    public convenience init<T : BinaryInteger>(exactly value: T) {
        self.init(Int(value))
    }

    /// Type to express the magnitude of a signed number. :nodoc:
    public typealias Magnitude = RbObject

    /// The magnitude of the value.
    ///
    /// Calls Ruby `magnitude`.
    public var magnitude: RbObject {
        do {
            return try call("magnitude")
        } catch {
            fatalError("Calling 'magnitude' on \(self) failed: \(error)")
        }
    }

    /// The negated version of the value.
    ///
    /// Calls Ruby unary -.
    public static prefix func -(_ operand: RbObject) -> RbObject {
        do {
            return try operand.call("-@")
        } catch {
            fatalError("Calling '-@' on \(operand) failed: \(error)")
        }
    }

    /// Unary plus operator.
    ///
    /// Calls Ruby unary +.
    public static prefix func +(_ operand: RbObject) -> RbObject {
        do {
            return try operand.call("+@")
        } catch {
            fatalError("Calling '+@' on \(operand) failed: \(error)")
        }
    }
}

// Add in division...

extension RbObject {

    public static func /(lhs: RbObject, rhs: RbObject) -> RbObject {
        do {
            return try lhs.call("/", args: [rhs])
        } catch {
            fatalError("Calling '/' on \(lhs) with \(rhs) failed: \(error)")
        }
    }

    public static func /=(lhs: inout RbObject, rhs: RbObject) {
        lhs = lhs / rhs
    }
}
