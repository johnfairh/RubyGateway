//
//  RbError.swift
//  RubyGateway
//
//  Distributed under the MIT license, see LICENSE
//
@preconcurrency internal import CRuby
internal import RubyGatewayHelpers

/// An error raised by the RubyGateway module.  Ruby exceptions
/// generate `RbError.rubyException(_:)`, unusual Ruby flow control
/// generates `RbError.rubyJump(_:)`, and the other cases correspond
/// to error conditions encountered by the Swift software.
public enum RbError: Error {

    // MARK: - Cases

    /// The Ruby VM could not be set up.
    case setup(String)

    /// An object has the wrong type for an operation.
    ///
    /// Raised for example when setting a CVar on a non-class object.
    case badType(String)

    /// A value passed to the library is out of range for some reason.
    ///
    /// Raised for example when declaring a method with fixed arity > 15.
    case badParameter(String)

    /// An identifier looks to be spelt wrong.
    ///
    /// Raised for example when an IVar name does not begin with '@'.
    case badIdentifier(type: String, id: String)

    /// A keyword argument is duplicated.
    ///
    /// Raised when a `kwArgs` parameter is passed and the list contains duplicate argument keywords.
    case duplicateKwArg(String)

    /// A Ruby exception occurred.
    ///
    /// You are free to ignore or handle this error.  If your code has been
    /// invoked from Ruby then you can also re-throw the error to pass it back
    /// down the stack.
    case rubyException(RbException)

    /// Some Ruby flow control has happened.
    ///
    /// Raised when you invoke a block from Swift and the block does `return` or `break`.
    /// You must do any Swift-side cleanup and re-throw the error without talking to Ruby,
    /// otherwise the Ruby runtime will become confused at best.
    case rubyJump(Int32)

    // MARK: - Error History

    /// Holds the most recent errors thrown by RubyGateway.
    ///
    /// This can be useful when the module indicates an error has occurred
    /// through a `nil` result somewhere -- the error causing the `nil` has
    /// still been generated internally and is stashed here.
    ///
    /// These `nil` results happen during type conversion to Swift, for example
    /// `String.init(_:)`, and when using the `RbObjectAccess.failable`
    /// adapter that suppresses throwing.
    ///
    /// Methods are thread-safe.
    public final class History: @unchecked Sendable {
        /// The error history.
        ///
        /// The oldest error recorded is at index 0; the most recent is at the
        /// end of the array.  See `mostRecent`.
        ///
        /// The list is automatically pruned, there is no need to worry about
        /// this consuming all your memory.
        public private(set) var errors: [RbError] = []
        private var lock: Lock = Lock()

        /// The most recent error encountered by RubyGateway.
        public var mostRecent: RbError? {
            lock.locked { errors.last } // I guess...
        }

        /// Clear the error history.
        public func clear() {
            lock.locked {
                errors = []
            }
        }

        /// Loads more than useful...
        private let MAX_RECENT_ERRORS = 12

        /// Record an `RbError`
        func record(error: RbError) {
            lock.locked {
                errors.append(error)
                if errors.count > MAX_RECENT_ERRORS {
                    errors = Array(errors.dropFirst())
                }
            }
        }

        /// Record an `RbException`
        func record(exception: RbException) {
            record(error: .rubyException(exception))
        }
    }

    /// Record an `RbError` and then throw it.
    static func raise(error: RbError) throws -> Never {
        history.record(error: error)
        throw error
    }

    /// A short history of errors thrown by RubyGateway
    public static let history = History()
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
        case let .badParameter(msg):
            return "Parameter has bad value: \(msg)"
        case let .badIdentifier(type, id):
            return "Bad Ruby identifier: '\(id)' does not look like \(type) name."
        case let .duplicateKwArg(key):
            return "Duplicate keyword arg \(key) on call()."
        case let .rubyException(exn):
            return "Ruby exception: \(exn)"
        case let .rubyJump(tag):
            return "Ruby jump flow control: \(tag)"
        }
    }
}

// MARK: - RbBreak

/// Throwing an instance of this type terminates and gives an overall
/// result to a Ruby block-based iteration like the Ruby `break` keyword.
///
/// ```swift
/// let result = myobj.call("each") { args in
///                  let derived = f(args[0])
///                  if g(derived) {
///                      throw RbBreak(with: derived)
///                  }
///                  return .nilObject
///              }
/// ```
public struct RbBreak: Error {
    let object: RbObject?

    /// Create an object to break out from a Ruby iterator.
    ///
    /// - parameter object: the value to give as the result of the iteration.
    ///                     Default `nil` equivalent to raw `break` in Ruby.
    public init(with object: RbObjectConvertible? = nil) {
        self.object = object?.rubyObject
    }
}

// MARK: - RbException

/// A Ruby exception.
///
/// This provides some convenience methods on top of the underlying `Exception`
/// object.  RubyGateway does not throw these directly, it always wraps them in
/// an `RbError` instance.
///
/// Create and throw one of these to raise a Ruby exception from
/// a block implemented in Swift by an `RbBlockCallback`.
public struct RbException: CustomStringConvertible, Error {
    /// The underlying Ruby exception object
    public let exception: RbObject

    init(exception: RbObject) {
        self.exception = exception
    }

    /// Construct a new Ruby `RuntimeError` exception with the given message.
    ///
    /// Use `Kernel#raise` directly to raise a different type of exception.
    public init(message: String) {
        exception = message.withCString { cstr in
            RbObject(rubyValue: rb_exc_new(rb_eRuntimeError, cstr, message.utf8.count))
        }
        RbError.history.record(exception: self)
    }

    /// Internal version for ArgumentError
    init(argMessage: String) {
        exception = argMessage.withCString { cstr in
            RbObject(rubyValue: rb_exc_new(rb_eArgError, cstr, argMessage.utf8.count))
        }
        RbError.history.record(exception: self)
    }

    /// The backtrace from the Ruby exception
    public var backtrace: [String] {
        var bt = ["[unbacktraceable]"]
        if let btObj = try? exception.get("backtrace"),
            let btStr = Array<String>(btObj) {
            bt = btStr
        }
        return bt
    }

    /// The exception's message
    public var description: String {
        let exceptionClass = try! exception.get("class")
        return "\(exceptionClass): \(exception)"
    }
}

// MARK: - Common handling for the Swift->C error path

extension UnsafeMutablePointer where Pointee == Rbg_return_value {
    func set(type: Rbg_return_type, value: VALUE) {
        pointee.type = type
        pointee.value = value
    }

    func setFrom(call: () throws -> VALUE) {
        do {
            let retVal = try call()
            set(type: RBG_RT_VALUE, value: retVal)
        } catch RbError.rubyException(let exn) {
            // RubyGateway/Ruby code threw exception
            set(type: RBG_RT_RAISE, value: exn.exception.withRubyValue { $0 })
        } catch RbError.rubyJump(let tag) {
            set(type: RBG_RT_JUMP, value: VALUE(tag))
        } catch let exn as RbException {
            // User Swift code generated Ruby exception
            set(type: RBG_RT_RAISE, value: exn.exception.withRubyValue { $0 })
        } catch let brk as RbBreak {
            // 'break' from iterator
            if let brkObject = brk.object {
                set(type: RBG_RT_BREAK_VALUE, value: brkObject.withRubyValue { $0 })
            } else {
                set(type: RBG_RT_BREAK, value: Qundef)
            }
        } catch {
            // User Swift code or RubyGateway threw Swift error.  Oh for typed throws.
            // Wrap it up in a Ruby exception and raise that instead!
            let rbExn = RbException(message: "Unexpected Swift error thrown: \(error)")
            set(type: RBG_RT_RAISE, value: rbExn.exception.withRubyValue { $0 })
        }
    }
}
