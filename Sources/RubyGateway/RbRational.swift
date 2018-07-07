//
//  RbRational.swift
//  RubyGateway
//
//  Distributed under the MIT license, see LICENSE
//

/// A simple interface to Ruby's rational number support.
///
/// This is not supposed to be a Swift rational number library.  It could be used
/// as an interface between one such and Ruby.
///
/// Ruby represents rational numbers internally as a positive or negative
/// integer numerator and a positive integer denominator.  Instances of this
/// `RbRational` type converted from Ruby objects follow these rules; instances
/// produced by Swift code using the `RbRational.init(numerator:denominator:)`
/// method may not.
///
/// ```swift
/// let myRat = RbRational(numerator: myFractionTop, denominator: myFractionBot)
///
/// let resultObj = myRubyService.call("addFinalSample", args: [myRat])
///
/// let myRatResult = RbRational(resultObj)
/// ```
public struct RbRational {
    /// The rational number's numerator
    public let numerator: Double
    /// The rational number's denominator
    public let denominator: Double

    /// Create a new rational number.  The parameters are normalized to give
    /// a positive denominator.
    public init(numerator: Double, denominator: Double) {
        if denominator < 0 {
            self.numerator = -numerator
            self.denominator = -denominator
        } else {
            self.numerator = numerator
            self.denominator = denominator
        }
    }
}

extension RbRational: RbObjectConvertible {
    /// Extract rational parts from a Ruby object.
    ///
    /// This calls `to_r` before extracting the parts so can
    /// be passed various types of Ruby object.
    ///
    /// Returns `nil` if the object cannot be converted or if its fractional
    /// parts parts cannot be converted to Swift `Double`s.
    /// See `RbError.history` to see why a conversion failed.
    public init?(_ value: RbObject) {
        guard let rat_obj = try? value.call("to_r"),
            let num_obj = try? rat_obj.call("numerator"),
            let denom_obj = try? rat_obj.call("denominator"),
            let num = Double(num_obj),
            let denom = Double(denom_obj) else {
                return nil
        }
        self.numerator = num
        self.denominator = denom
    }

    /// Convert some Swift data type to a rational.
    ///
    /// This is a convenience wrapper that lets you access Ruby's
    /// rational library directly from Swift types, for example:
    /// ```swift
    /// let rat = RbRational(0.3)
    /// ```
    public init?(_ value: RbObjectConvertible) {
        self.init(value.rubyObject)
    }

    /// Get a Ruby version of a rational number.
    ///
    /// This can theoretically produce `RbObject.nilObject` if the environment
    /// has been nobbled in some way.
    public var rubyObject: RbObject {
        guard Ruby.softSetup(),
            let ratObject = try? Ruby.call("Rational", args: [numerator, denominator]) else {
                return .nilObject
        }
        return ratObject
    }
}
