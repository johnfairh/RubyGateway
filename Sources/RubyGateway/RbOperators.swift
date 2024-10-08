//
//  RbOperators.swift
//  RubyGateway
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

// MARK: - SignedNumeric

extension RbObject: SignedNumeric {
    /// Create a Ruby object from some type conforming to `BinaryInteger`
    public convenience init<T : BinaryInteger>(exactly value: T) {
        self.init(Int(value))
    }

    /// Type to express the magnitude of a signed number. :nodoc:
    public typealias Magnitude = RbObject

    /// Subtraction operator for `RbObject`s.
    ///
    /// - note: Calls Ruby `-` method.  Crashes the process (`fatalError`)
    ///         if the objects do not support subtraction.
    public static func -(lhs: RbObject, rhs: RbObject) -> RbObject {
        do {
            return try lhs.call("-", args: [rhs])
        } catch {
            fatalError("Calling '-' on \(lhs) with \(rhs) failed: \(error)")
        }
    }

    /// Addition operator for `RbObject`s.
    ///
    /// - note: Calls Ruby `+` method.  Crashes the process (`fatalError`)
    ///         if the objects do not support addition.
    public static func +(lhs: RbObject, rhs: RbObject) -> RbObject {
        do {
            return try lhs.call("+", args: [rhs])
        } catch {
            fatalError("Calling '+' on \(lhs) with \(rhs) failed: \(error)")
        }
    }

    /// Multiplication operator for `RbObject`s.
    ///
    /// - note: Calls Ruby `*` method.  Crashes the process (`fatalError`)
    ///         if the objects do not support multiplication.
    public static func *(lhs: RbObject, rhs: RbObject) -> RbObject {
        do {
            return try lhs.call("*", args: [rhs])
        } catch {
            fatalError("Calling '*' on \(lhs) with \(rhs) failed: \(error)")
        }
    }

    /// Division operator for `RbObject`s.
    ///
    /// - note: Calls Ruby `/` method.  Crashes the process (`fatalError`)
    ///         if the objects do not support division.
    public static func /(lhs: RbObject, rhs: RbObject) -> RbObject {
        do {
            return try lhs.call("/", args: [rhs])
        } catch {
            fatalError("Calling '/' on \(lhs) with \(rhs) failed: \(error)")
        }
    }

    /// Remainder operator for `RbObject`s.
    ///
    /// - note: Calls Ruby `%` method.  Crashes the process (`fatalError`)
    ///         if the objects do not support remaindering.
    public static func %(lhs: RbObject, rhs: RbObject) -> RbObject {
        do {
            return try lhs.call("%", args: [rhs])
        } catch {
            fatalError("Calling '%' on \(lhs) with \(rhs) failed: \(error)")
        }
    }

    // OK why do these not have default implementations?

    /// Addition-assignment operator for `RbObject`s.
    public static func +=(lhs: inout RbObject, rhs: RbObject) {
        lhs = lhs + rhs
    }

    /// Subtraction-assignment operator for `RbObject`s.
    public static func -=(lhs: inout RbObject, rhs: RbObject) {
        lhs = lhs - rhs
    }

    /// Multiplication-assignment operator for `RbObject`s.
    public static func *=(lhs: inout RbObject, rhs: RbObject) {
        lhs = lhs * rhs
    }

    /// Division-assignment operator for `RbObject`s.
    public static func /=(lhs: inout RbObject, rhs: RbObject) {
        lhs = lhs / rhs
    }

    /// Remainder-assignment operator for `RbObject`s.
    public static func %=(lhs: inout RbObject, rhs: RbObject) {
        lhs = lhs % rhs
    }

    /// The magnitude of the value.
    ///
    /// - note: Calls Ruby `magnitude` method.  Crashes the process (`fatalError`)
    ///         if the object does not support magnitude.
    public var magnitude: RbObject {
        do {
            return try call("magnitude")
        } catch {
            fatalError("Calling 'magnitude' on \(self) failed: \(error)")
        }
    }

    /// The negated version of the value.
    ///
    /// - note: Calls Ruby unary - method.  Crashes the process (`fatalError`)
    ///         if the object does not support this.
    public static prefix func -(_ operand: RbObject) -> RbObject {
        do {
            return try operand.call("-@")
        } catch {
            fatalError("Calling '-@' on \(operand) failed: \(error)")
        }
    }

    /// Unary plus operator.
    ///
    /// - note: Calls Ruby unary + method.  Crashes the process (`fatalError`)
    ///         if the object does not support this.
    public static prefix func +(_ operand: RbObject) -> RbObject {
        do {
            return try operand.call("+@")
        } catch {
            fatalError("Calling '+@' on \(operand) failed: \(error)")
        }
    }
}

// MARK: - Subscript

extension RbObject {
    /// Subscript operator, supports both get + set.
    ///
    /// Although you can use `RbObjectConvertible`s as the subscript arguments,
    /// the value assigned in the setter has to be an `RbObject`.  So this doesn't
    /// work:
    /// ```swift
    /// try myObj[1, "fish", myThirdParamObj] = 4
    /// ```
    /// ...instead you have to do:
    /// ```swift
    /// try myObj[1, "fish", myThirdParamObj] = RbObject(4)
    /// ```
    ///
    /// - note: Calls Ruby `[]` and `[]=` methods.  Crashes the process (`fatalError`)
    ///         if anything goes wrong - Swift can't throw from subscripts yet.
    public subscript(args: any RbObjectConvertible...) -> RbObject {
        get {
            do {
                return try call("[]", args: args)
            } catch {
                fatalError("RbObject[] failed: \(error)")
            }
        }
        set {
            let allArgs = args + [newValue.rubyObject]
            do {
                try call("[]=", args: allArgs)
            } catch {
                fatalError("RbObject.[]= failed: \(error)")
            }
        }
    }
}
