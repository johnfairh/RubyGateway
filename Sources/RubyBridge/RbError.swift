//
//  RbError.swift
//  TMLRuby
//
//  Created by John Fairhurst on 13/02/2018.
//
import CRuby

/// Errors raised by `RubyBridge` layer itself
public enum RbError: Error {
    /// Ruby VM could not be initialized.
    case initError(String)
}

// MARK: - CustomStringConvertible

extension RbError: CustomStringConvertible {
    /// Human-readable description of the error.
    public var description: String {
        switch self {
        case let .initError(msg): return msg;
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
