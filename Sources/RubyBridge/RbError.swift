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
}

// MARK: - CustomStringConvertible

extension RbError: CustomStringConvertible {
    /// Human-readable description of the error.
    public var description: String {
        switch self {
        case let .setup(msg): return msg
        case let .notClass(msg): return msg
        }
    }
}

/// Corresponds to a Ruby exception
public struct RbException: Error {
    public let value: VALUE
    public init(rubyValue: VALUE) {
        value = rubyValue
    }
}
