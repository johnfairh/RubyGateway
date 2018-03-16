//
//  RbError.swift
//  RubyBridge
//
//  Distributed under the MIT license, see LICENSE
//
import CRuby

/// An error raised by the `RubyBridge` module.  Ruby exceptions
/// generate `RbError.rubyException`, the other cases correspond
/// to error conditions encountered by the Swift software.
public enum RbError: Error {

    // MARK: - Cases

    /// The Ruby VM could not be set up.
    case setup(String)

    /// An object has the wrong type for an operation.
    ///
    /// Raised for example when setting a CVar on a non-class object.
    case badType(String)

    /// An identifier looks to be spelt wrong.
    ///
    /// Raised for example when an IVar name does not begin with '@'.
    case badIdentifier(type: String, id: String)

    /// A keyword argument is duplicated.
    ///
    /// Raised when a `kwArgs` parameter is passed and the list contains duplicate argument keywords.
    case duplicateKwArg(String)

    /// A Ruby exception occurred.
    case rubyException(RbException)

    // MARK: - Error History

    /// Holds the most recent errors thrown by `RubyBridge`.
    ///
    /// This can be useful when the module indicates an error has occurred
    /// through a `nil` result somewhere -- the error causing the `nil` has
    /// still been generated internally and is stashed here.
    ///
    /// These `nil` results happen during type conversion to Swift, for example
    /// `String.init(_:)`, and when using the `RbObjectAccess.failable`
    /// adapter that suppresses throwing.
    public struct History {
        /// The error history.
        ///
        /// The oldest error recorded is at index 0; the most recent is at the
        /// end of the array.  See `mostRecent`.
        ///
        /// The list is automatically pruned, there is no need to worry about
        /// this consuming all your memory.
        public private(set) var errors: [RbError] = []

        /// The most recent error encountered by `RubyBridge`.
        public var mostRecent: RbError? {
            return errors.last
        }

        /// Clear the error history.
        public mutating func clear() {
            errors = []
        }

        /// Loads more than useful...
        private let MAX_RECENT_ERRORS = 12

        /// Record an `RbError`
        mutating func record(error: RbError) {
            errors.append(error)
            if errors.count > MAX_RECENT_ERRORS {
                errors = Array(errors.dropFirst())
            }
        }

        /// Record an `RbException`
        mutating func record(exception: RbException) {
            record(error: .rubyException(exception))
        }
    }

    /// Record an `RbError` and then throw it.
    static func raise(error: RbError) throws -> Never {
        history.record(error: error)
        throw error
    }

    /// A short history of errors thrown by `RubyBridge`
    public static var history = History()
    // TODO: Fix locking....
}

// MARK: - CustomStringConvertible

extension RbError: CustomStringConvertible {
    /// A human-readable description of the error.
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

// MARK: - RbBreak

/// `RbBreak.doBreak(with:)` provides the way of terminating and giving an
/// overall result to a Ruby block-based iteration like the Ruby `break`.
///
/// ```swift
/// let result = myobj.call("each") { item in
///                  let derived = f(item)
///                  if g(derived) {
///                      try RbBreak.doBreak(with: derived)
///                  }
///              }
/// ```
public struct RbBreak: Error {
    let object: RbObject?

    init(with object: RbObject?) {
        self.object = object
    }

    /// Break out from a Ruby iterator.
    ///
    /// - parameter object: the value to give as the result of the iteration.
    ///                     Default `nil` equivalent to raw `break` in Ruby.
    public static func doBreak(with object: RbObjectConvertible? = nil) throws -> Never {
        throw RbBreak(with: object?.rubyObject)
    }
}

// MARK: - RbException

/// A Ruby exception.
///
/// This provides some convenience methods on top of the underlying `Exception`
/// object.  `RubyBridge` does not throw these directly, it always wraps them in
/// an `RbError` instance.
public struct RbException: CustomStringConvertible, Error {
    /// The underlying Ruby exception object
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

    /// Construct a new Ruby exception with the given message
    public init(message: String) {
        exception = message.withCString { cstr in
            RbObject(rubyValue: rb_exc_new(rb_eRuntimeError, cstr, message.utf8.count))
        }
        RbError.history.record(exception: self)
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

    /// The exception's message
    public var description: String {
        let exceptionClass = try! exception.get("class")
        return "\(exceptionClass): \(exception)"
    }
}
