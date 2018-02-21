//
//  RbBridge.swift
//  RubyBridge
//
//  Distributed under the MIT license, see LICENSE
//

import CRuby
import RubyBridgeHelpers

/// This is a top-level wrapper to Ruby.  It provides information about the VM,
/// some control over how code is run, and services to access the various kinds
/// of Ruby objects.
///
/// The Ruby VM is initialized when it is first accessed and normally not stopped
/// until the process ends.  The VM can be manually shut down by calling `RbBridge.cleanup()`
/// but once this has been done the VM cannot be restarted.
///
/// The loadpath (where `require` looks) is set to the `lib/ruby` directories
/// adjacent to the `libruby` the program is linked against and `$RUBYLIB`.
/// Gems are enabled.
///
/// There is a built-in instance of `RbBridge` called `Ruby`.  This lets you
/// write things like
///
/// ```swift
/// import RubyBridge
///
/// print("Ruby version is \(Ruby.version)")
///
/// do {
///    Ruby.require("rouge")
///    my html = Ruby.getModule("Rouge").call("highlight", "let a = 1", "swift", "html")
/// } catch {
/// }
/// ```
///
/// Or with a simpler syntax:
///
/// ```swift
/// do {
///    Ruby.require("rouge")
///    my html = Ruby.do("Rouge").do("highlight", "let a = 1", "swift", "html")
/// } catch {
/// }
/// ```
///
/// Or if you don't like exceptions:
///
/// ```swift
/// Ruby.require("rouge")
/// my html = Ruby.failable.do("Rouge")?.do("highlight", "let a = 1", "swift", "html")
/// ```
///
/// Or with dynamic-member-lookup:
/// ```swift
/// my html = Ruby.Rouge?.highlight("let a = 1", "swift", "html")
/// ```
open class RbBridge {

    /// The VM - not intialized until `setup()` is called.
    private static let vm = RbVM()

    /// Initialize Ruby.  Throw an error if Ruby is not working.
    /// Called by anything that might by the first op.
    func setup() throws {
        try RbBridge.vm.setup()
    }

    public func cleanup() -> Int32 {
        return RbBridge.vm.cleanup()
    }

    /// Get an `ID` ready to call a method, for example.
    ///
    /// This is public for users to interop with `CRuby`, it is not
    /// needed for regular `RubyBridge` use.
    ///
    /// - parameter name: name to look up, typically constant or method name.
    /// - returns: the corresponding ID
    /// - throws: `RbException` if Ruby raises -- probably means the `ID` space
    ///   is full, which is fairly unlikely.
    public func getID(for name: String) throws -> ID {
        return try RbBridge.vm.getID(for: name)
    }

    private func softSetup() {
        let _ = try? setup()
    }
}

extension RbBridge {

    /// Debug mode for Ruby code, sets `$DEBUG` / `$-d`
    public var debug: Bool {
        get {
            softSetup()
            guard let debug_ptr = rb_ruby_debug_ptr() else {
                // Current implementation can't fail but let's not crash.
                return false
            }
            return debug_ptr.pointee == Qtrue;
        }
        set {
            softSetup()
            guard let debug_ptr = rb_ruby_debug_ptr() else {
                return
            }
            let newVal = newValue ? Qtrue : Qfalse
            debug_ptr.initialize(to: newVal)
        }
    }

    /// Verbose setting for Ruby scripts - affects `Kernel#warn` etc.
    public enum Verbosity {
        case none
        case medium
        case full
    }

    /// Verbose mode for Ruby code, sets `$VERBOSE` / `$-v`
    public var verbose: Verbosity {
        get {
            softSetup()
            guard let verbose_ptr = rb_ruby_verbose_ptr() else {
                // Current implementation can't fail but let's not crash.
                return .none
            }
            switch verbose_ptr.pointee {
            case Qnil: return .none
            case Qfalse: return .medium
            default: return .full
            }
        }
        set {
            softSetup()
            guard let verbose_ptr = rb_ruby_verbose_ptr() else {
                return
            }
            let newVal: VALUE
            switch newValue {
            case .none: newVal = Qnil
            case .medium: newVal = Qfalse
            case .full: newVal = Qtrue
            }
            verbose_ptr.initialize(to: newVal)
        }
    }

    /// Set `$PROGRAM_NAME` / `$0` for Ruby code.
    public var scriptName: String {
        set {
            softSetup()
            ruby_script(newValue)
        }
        get {
            // sigh
            do {
                // XXX fix me - globalv lookup plus string conversion...
                let _ = try eval(ruby: "$PROGRAM_NAME")
                return "This needs to be implemented"
            } catch {
                return "??"
            }
        }
    }

    /// The version number triple of Ruby being used, for example "2.5.0".
    public var version: String {
        return String(cString: rbb_ruby_version())
    }

    /// The full version string for the Ruby being used.
    /// For example "ruby 2.5.0p0 (2017-12-25 revision 61468) [x86_64-darwin17]".
    public var versionDescription: String {
        return String(cString: rbb_ruby_description())
    }
}

// MARK: - run code: eval, require, load

extension RbBridge {

    /// Evaluate some Ruby and return the result.
    /// XXX fix this up [turn into 'call' of Object#eval?]
    public func eval(ruby: String) throws -> VALUE {
        try setup()
        var state: Int32 = 0
        let value = rb_eval_string_protect(ruby, &state)
        if state != 0 {
            let exception = rb_errinfo()
            defer { rb_set_errinfo(Qnil) }
            throw RbException(rubyValue: exception)
        }
        return value
    }

    /// 'require' - see Ruby `Kernel#require`.  Load file once-only.
    ///
    /// - returns: `true` if the filed was opened OK, `false` if it is already loaded.
    /// - throws: RbException if a Ruby exception occurred.  (This usually means the
    ///           file couldn't be found.)
    @discardableResult
    public func require(filename: String) throws -> Bool {
        try setup()
        var state = Int32(0)
        let value = rbb_require_protect(filename, &state);
        if state != 0 {
            let exception = rb_errinfo()
            defer { rb_set_errinfo(Qnil) }
            throw RbException(rubyValue: exception)
        }
        return value == Qtrue
    }
}

// MARK: - Constant access from an object

extension RbBridge: RbConstantScope {
    func constantScopeValue() throws -> VALUE {
        try setup()
        return rb_cObject
    }
}

// MARK: - Global declaration

public let Ruby = RbBridge()
