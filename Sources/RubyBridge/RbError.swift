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
    /// Object has the wrong type for an operation.
    case badType(String)
    /// Identifier looks wrong.
    case badIdentifier(type: String, id: String)
    /// Duplicate keyword arg.
    case duplicateKwArg(String)
    /// Ruby exception occurred.
    case rubyException(RbException)

    public static func recordAndThrow(error: RbError) throws -> Never {
        throw error
    }
    public static func record(exception: RbException) {
    }
}

// MARK: - CustomStringConvertible

extension RbError: CustomStringConvertible {
    /// Human-readable description of the error.
    public var description: String {
        switch self {
        case let .setup(msg):
            return "Can't set up Ruby: \(msg)"
        case let .badType(msg):
            return "Object has bad type: \(msg)"
        case let .badIdentifier(type, id):
            return "Bad Ruby identifier: '\(id)' does not look like \(type) name."
        case let .duplicateKwArg(key):
            return "Duplicate keyword arg \(key) on call()."
        case let .rubyException(exn):
            return "Ruby exception: \(exn)"
        }
    }
}

/// Corresponds to a Ruby exception
public struct RbException: CustomStringConvertible {
    /// The underlying Ruby exception
    public let exception: RbObject

    /// Initialize a new `RbException` if Ruby has a pending exception.
    /// Clears any such pending Ruby exception, transferring responsibility
    /// to the Swift domain.
    init?() {
        let exceptionObj = RbObject(rubyValue: rb_errinfo())
        guard !exceptionObj.isNil else {
            return nil
        }
        rb_set_errinfo(Qnil)

        self.exception = exceptionObj
    }

    /// Check + clear exception status.  Record any exception so it can
    /// be inspected later on.  Return whether an exception was swallowed.
    static func ignoreAnyPending() -> Bool {
        guard let exception = RbException() else {
            return false
        }
        RbError.record(exception: exception)
        return true
    }

    // TODO: Sort out arrays and make this better
    /// The backtrace from the Ruby exception
    public var backtrace: String {
        guard let btObj = try? exception.get("backtrace"),
              let btStr = String(btObj) else {
            return "[unbacktraceable]"
        }
        return btStr
    }

    /// The Ruby exception's message
    public var description: String {
        return String(exception) ?? "[Indescribable]"
    }
}
