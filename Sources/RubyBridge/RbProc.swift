//
//  RbProc.swift
//  RubyGateway
//
//  Distributed under the MIT license, see LICENSE
//

import CRuby
import RubyGatewayHelpers

/// A Ruby Proc.
///
/// Use this to create a Ruby Proc from a symbol or any Ruby object
/// supporting `to_proc`.
///
/// This is most useful when passing a block to a method:
/// ```swift
/// // Ruby: mapped = names.map(&:downcase)
/// let mapped = names.call("map", block: RbProc(RbSymbol("downcase")))
/// ```
///
/// Use `RbObject.init(blockCall:)` to create a Ruby Proc from a
/// Swift closure.
///
/// If you want to pass Swift code to a method as a block then just call
/// `RbObjectAccess.call(_:args:kwArgs:blockRetention:blockCall:)` directly,
/// no need for either `RbProc` or `RbObject`.
public struct RbProc: RbObjectConvertible {
    private let sourceObject: RbObjectConvertible

    /// Initialize from something that can be turned into a Ruby object.
    public init(object: RbObjectConvertible) {
        sourceObject = object
    }

    /// Try to initialize from a Ruby object.
    ///
    /// Succeeds if the object can be used as a Proc (has `to_proc`).
    public init?(_ value: RbObject) {
        guard let obj = try? value.call("respond_to?", args: ["to_proc"]),
            obj.isTruthy else {
            return nil
        }
        self.init(object: value)
    }

    /// A Ruby object for the Proc
    public var rubyObject: RbObject {
        let srcObj = sourceObject.rubyObject
        guard Ruby.softSetup(),
            let procObj = try? srcObj.call("to_proc") else {
            return .nilObject
        }
        return procObj
    }
}
