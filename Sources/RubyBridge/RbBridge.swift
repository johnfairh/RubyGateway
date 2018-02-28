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
///    try Ruby.require("rouge")
///    let html = try Ruby.getModule("Rouge").call("highlight", args: ["let a = 1", "swift", "html"])
/// } catch {
/// }
/// ```
///
/// Or with a simpler syntax:
///
/// ```swift
/// do {
///    try Ruby.require("rouge")
///    let html = try Ruby.do("Rouge").do("highlight", args: ["let a = 1", "swift", "html"])
/// } catch {
/// }
/// ```
///
/// Or if you don't like exceptions:
///
/// ```swift
/// try! Ruby.require("rouge")
/// let html = Ruby.failable.do("Rouge")?.do("highlight", "let a = 1", "swift", "html")
/// ```
///
/// Or with Swift 5 dynamic member lookup & callable:
/// ```swift
/// let html = Ruby.Rouge?.highlight("let a = 1", "swift", "html")
/// ```
public final class RbBridge: RbConstantAccess, RbInstanceAccess {

    /// The VM - not intialized until `setup()` is called.
    static let vm = RbVM()

    /// Initialize Ruby.  Throw an error if Ruby is not working.
    /// Called by anything that might by the first op.
    func setup() throws {
        if try RbBridge.vm.setup() {
            // Work around Swift not calling static deinit...
            atexit { RbBridge.vm.cleanup() }
        }
    }

    /// Explicitly shut down Ruby and release resources.
    /// This includes calling `END{}` code and procs registered by `Kernel.#at_exit`.
    ///
    /// You generally don't need to call this, will be done automatically
    /// as part of process exit.
    ///
    /// If called you cannot continue to use Ruby in this process, the VM cannot be
    /// re-setup().
    ///
    /// - returns: 0 if the cleanup went fine, otherwise some error code from Ruby.
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

    /// Attempt to initialize Ruby but swallow any error.
    ///
    /// This is for use from places that could be the first use of Ruby but it
    /// is not practical to throw an exception for API or aesthetic reasons.
    ///
    /// The idea is that callers can get by long enough for the user to call
    /// `require()` or `send()` which will properly report the VM setup error.
    public func softSetup() -> Bool {
        if let _ = try? setup() {
            return true
        }
        return false
    }

    /// The id of the Ruby `Object` class.  Used to provide access to constants from the
    /// top level and global functions via the `RbConstantAccess` and `RbInstanceAccess`
    /// protocols. :nodoc:
    public var rubyValue: VALUE {
        return rb_cObject
    }
}

// MARK: - VM properties

extension RbBridge {

    /// Debug mode for Ruby code, sets `$DEBUG` / `$-d`
    public var debug: Bool {
        get {
            guard softSetup(), let debug_ptr = rb_ruby_debug_ptr() else {
                // Current implementation can't fail but let's not crash.
                return false
            }
            return debug_ptr.pointee == Qtrue;
        }
        set {
            guard softSetup(), let debug_ptr = rb_ruby_debug_ptr() else {
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
            guard softSetup(), let verbose_ptr = rb_ruby_verbose_ptr() else {
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
            guard softSetup(), let verbose_ptr = rb_ruby_verbose_ptr() else {
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
            if softSetup() {
                ruby_script(newValue)
            }
        }
        get {
            // sigh
            guard softSetup(),
                let nameObj = try? getGlobalVar("$PROGRAM_NAME"),
                let name = String(nameObj) else {
                return ""
            }
            return name
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
    public func eval(ruby: String) throws -> RbObject {
        try setup()
        return RbObject(rubyValue: try RbVM.doProtect {
            rb_eval_string_protect(ruby, nil)
        })
    }

    /// 'require' - see Ruby `Kernel#require`.  Load file once-only.
    ///
    /// - parameter filename: The name of the file to load.
    /// - returns: `true` if the filed was loaded OK, `false` if it is already loaded.
    /// - throws: RbException if a Ruby exception occurred.  (This usually means the
    ///           file couldn't be found.)
    @discardableResult
    public func require(filename: String) throws -> Bool {
        // Have to use eval so that gems work - rubygems/kernel_require.rb replaces
        // `Kernel#require` so it can do the gem thing, so `rb_require` is no good.
        return try eval(ruby: "require '\(filename)'").isTruthy
    }

    /// 'load' - see Ruby `Kernel#load`. Load a file, reloads if already loaded.
    ///
    /// - parameter filename: The name of the file to load
    /// - parameter wrap: If `true`, load the file into a fresh anonymous namespace
    ///   instead of the current program.  See `Kernel#load`.
    /// - throws: `RbException` for any Ruby exception raised.
    public func load(filename: String, wrap: Bool = false) throws {
        try setup()
        let filenameObj = RbObject(filename)
        return try RbVM.doProtect {
            rbb_load_protect(filenameObj.rubyValue, wrap ? 1 : 0, nil)
        }
    }
}

// MARK: - Instance variable access

// Instance variables at the top level are associated with the 'top' object
// that is unfortunately hidden from the public API (`rb_vm_top_self()`).  So
// we have to use `eval` these.  Reading is easy enough; writing an arbitrary
// VALUE is impossible to do without shenanigans.

extension RbBridge {
    private static var ivarWorkaroundName: String {
        return "$RbBridgeTopSelfIvarWorkaround"
    }

    /// Get the value of a top-level instance variable.  Creates a new one with a nil value
    /// if it doesn't exist yet.
    ///
    /// This is like doing `@f` at the top level of a Ruby script.
    ///
    /// - parameter name: Name of ivar to get.  Should begin with single `@`.
    /// - returns: Value of the ivar or nil if it has not been assigned yet.
    /// - throws: `RbError` if `name` looks wrong. `RbException` if Ruby has a problem.
    public func getInstanceVar(_ name: String) throws -> RbObject {
        try setup()
        try name.checkRubyInstanceVarName()
        return try eval(ruby: name)
    }

    /// Set a top-level instance variable.  Creates a new one if it doesn't exist yet.
    ///
    /// This is like doing `@f = 3` at the top level of a Ruby script.
    ///
    /// - parameter name: Name of ivar to set.  Should begin with single `@`.
    /// - parameter newValue: New value to set.
    /// - returns: The value that was set.
    /// - throws: `RbError` if `name` looks wrong. `RbException` if Ruby has a problem.
    @discardableResult
    public func setInstanceVar(_ name: String, newValue: RbObjectConvertible) throws -> RbObject {
        try setup()
        try name.checkRubyInstanceVarName()
        let oldValue = try getGlobalVar(RbBridge.ivarWorkaroundName)
        try setGlobalVar(RbBridge.ivarWorkaroundName, newValue: newValue)
        defer { let _ = try? setGlobalVar(RbBridge.ivarWorkaroundName, newValue: oldValue) }
        return try eval(ruby: "\(name) = \(RbBridge.ivarWorkaroundName)")
        // TODO: could simplify if we had hooked global vars...
    }
}

// MARK: - Global declaration

public let Ruby = RbBridge()
