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

    /// Holds the most recent errors thrown by `RubyBridge`.
    /// This can be useful when error throwing is disabled - although
    /// the API returns `nil` the error is still generated internally
    /// and stashed here.
    public struct History {
        /// The error history.  The oldest error recorded is at index 0;
        /// the most recent is at the end of the array.  See `mostRecent`.
        public private(set) var errors: [RbError] = []

        /// The most recent error thrown by `RubyBridge`.
        public var mostRecent: RbError? {
            return errors.last
        }

        /// Clear the error history.
        public mutating func clear() {
            errors = []
        }

        /// Loads more than useful...
        private let MAX_RECENT_ERRORS = 12

        mutating func record(error: RbError) {
            errors.append(error)
            if errors.count > MAX_RECENT_ERRORS {
                errors = Array(errors.dropFirst())
            }
        }

        mutating func record(exception: RbException) {
            record(error: .rubyException(exception))
        }
    }

    static func raise(error: RbError) throws -> Never {
        history.record(error: error)
        throw error
    }

    /// A short history of errors thrown by `RubyBridge`
    public static var history = History()
    // TODO: locking....
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

// MARK: - RbException

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
        RbError.history.record(exception: exception)
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
        let exceptionClass = try! exception.get("class")
        return "\(exceptionClass): \(exception)"
    }
}
