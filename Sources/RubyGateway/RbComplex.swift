//
//  RbComplex.swift
//  RubyGateway
//
//  Distributed under the MIT license, see LICENSE
//

/// A simple interface to Ruby's complex number support.
///
/// This is not supposed to be a Swift complex number library.  It could be used
/// as an interface between one such and Ruby.
///
/// Ruby always represents complex numbers internally using rectangular coordinates
/// so this type does not offer any direct support for polar coordinates.
///
public struct RbComplex {
    /// The real part of the complex number
    public let real: Double
    /// The imaginary part of the complex number
    public let imaginary: Double

    /// Create a new complex number from real and imaginary parts.
    public init(real: Double, imaginary: Double) {
        self.real = real
        self.imaginary = imaginary
    }
}

extension RbComplex: RbObjectConvertible {
    /// Create a complex number from a Ruby object.
    ///
    /// This calls `to_c` before extracting real and imaginary parts so can
    /// be passed various types of Ruby object.
    ///
    /// Returns `nil` if the object cannot be converted or if its real and
    /// imaginary parts cannot be converted to Swift `Double`s.
    /// See `RbError.history` to see why a conversion failed.
    public init?(_ value: RbObject) {
        guard let complex_obj = try? value.call("to_c"),
            let real_obj = try? complex_obj.call("real"),
            let imaginary_obj = try? complex_obj.call("imaginary"),
            let real = Double(real_obj),
            let imaginary = Double(imaginary_obj) else {
                return nil
        }
        self.real = real
        self.imaginary = imaginary
    }

    /// Get a Ruby version of a complex number.
    ///
    /// This can theoretically produce `RbObject.nilObject` if the `Complex`
    /// class has been nobbled in some way.
    public var rubyObject: RbObject {
        guard Ruby.softSetup(),
            let complexClass = try? Ruby.get("Complex"),
            let complexObject = try? complexClass.call("rectangular", args: [real, imaginary]) else {
                return .nilObject
        }
        return complexObject
    }
}
