//
//  RbError.swift
//  RubyBridge
//
//  Distributed under the MIT license, see LICENSE
//
import CRuby

/// Errors raised by `RubyBridge` layer itself
public enum RbError: Error {
    /// Ruby VM could not be set up.
    case setup(String)
    /// Constant is not a Class
    case notClass(String)
    /// Identifier looks wrong
    case badIdentifier(type: String, id: String)
    /// Duplicate keyword arg
    case duplicateKwArg(first: RbObject, second: RbObject)
}

// MARK: - CustomStringConvertible

extension RbError: CustomStringConvertible {
    /// Human-readable description of the error.
    public var description: String {
        switch self {
        case let .setup(msg): return msg
        case let .notClass(msg): return msg
        case let .badIdentifier(type, id):
            return "Bad Ruby identifier: '\(id)' does not look like \(type) name."
        case let .duplicateKwArg(first, second):
            return "Duplicate keyword arg on call.  First value \(first), second value \(second)."
        }
    }
}

/// Corresponds to a Ruby exception
public struct RbException: Error, CustomStringConvertible {
    public let exception: RbObject
    public init(rubyValue: VALUE) {
        exception = RbObject(rubyValue: rubyValue)
    }
    public var description: String {
        return String(exception) ?? "[Indescribable]"
    }
}
