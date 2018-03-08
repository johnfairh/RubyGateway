//
//  RbBridge.swift
//  RubyBridge
//
//  Distributed under the MIT license, see LICENSE
//

import CRuby
import RubyBridgeHelpers

/// Provides information about the Ruby VM, some control over how code is run,
/// and services to access various kinds of Ruby objects from the top level.
///
/// You cannot instantiate this type.  Instead `RubyBridge` exports a public
/// instance `Ruby`.  Among other things this permits dynamic member lookup
/// and callable-style programming in Swift 5.
///
/// The Ruby VM is initialized when the object is first accessed and is
/// automatically stopped when the process ends.  The VM can be manually shut
/// down before process exit by calling `RbBridge.cleanup()` but once this has
/// been done the VM cannot be restarted and subsequent calls to `RubyBridge`
/// services will fail.
///
/// The loadpath (where `require` looks) is set to the `lib/ruby` directories
/// adjacent to the `libruby` the program is linked against and `$RUBYLIB`.
/// RubyGems are enabled.
///
/// ## Accessing Ruby objects
///
/// The class inherits from `RbObjectAccess` which lets you look up constants
/// or call functions as you would at the top level of a Ruby script, for example:
/// ```swift
/// import RubyBridge
///
/// print("Ruby version is \(Ruby.version)")
///
/// do {
///    try Ruby.require("rouge")
///    let html = try Ruby.get("Rouge").call("highlight", args: ["let a = 1", "swift", "html"])
/// } catch {
/// }
/// ```
///
/// Or with Swift 5 dynamic member lookup & callable:
/// ```swift
/// let html = Ruby.Rouge!.highlight("let a = 1", "swift", "html")!
/// ```
///
/// If you just want to create a Ruby object of some class, see
/// `RbObject.init(ofClass:args:kwArgs:)`.
public final class RbBridge: RbObjectAccess {

    /// The VM - not intialized until `setup()` is called.
    static let vm = RbVM()

    init() {
        super.init(getValue: { rb_cObject })
    }

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
    /// You generally don't need to call this: it happens automatically as part of
    /// process exit.
    ///
    /// Once called you cannot continue to use Ruby in this process: the VM cannot
    /// be re-setup.
    ///
    /// - returns: 0 if the cleanup went fine, otherwise some error code from Ruby.
    public func cleanup() -> Int32 {
        return RbBridge.vm.cleanup()
    }

    /// Get an `ID` ready to call a method, for example.
    ///
    /// This is public to permit interop with `CRuby`.  It is not
    /// needed for regular `RubyBridge` use.
    ///
    /// - parameter name: Name to look up, typically constant or method name.
    /// - returns: The corresponding ID.
    /// - throws: `RbException` if Ruby raises an exception.  This probably means
    ///   the `ID` space is full, which is fairly unlikely.
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
    func softSetup() -> Bool {
        if let _ = try? setup() {
            return true
        }
        return false
    }

    // MARK: - Top self instance variable access

    // Can't put this lot in an extension because overrides....

    // Instance variables at the top level are associated with the 'top' object
    // that is unfortunately hidden from the public API (`rb_vm_top_self()`).  So
    // we have to use `eval` these.  Reading is easy enough; writing an arbitrary
    // VALUE is impossible to do without shenanigans.

    private static var ivarWorkaroundName = "$RbBridgeTopSelfIvarWorkaround"

    /// Get the value of a top-level instance variable.  Creates a new one with a `nil`
    /// value if it doesn't exist yet.
    ///
    /// This is like doing `@f` at the top level of a Ruby script.
    ///
    /// For a version that does not throw, see `RbObjectAccess.failable`.
    ///
    /// - parameter name: Name of IVar to get.  Must begin with a single '@'.
    /// - returns: Value of the IVar or Ruby `nil` if it has not been assigned yet.
    /// - throws: `RbError.badIdentifier` if `name` looks wrong.
    ///           `RbError.rubyException` if Ruby has a problem.
    public override func getInstanceVar(_ name: String) throws -> RbObject {
        try setup()
        try name.checkRubyInstanceVarName()
        return try eval(ruby: name)
    }

    /// Set a top-level instance variable.  Creates a new one if it doesn't exist yet.
    ///
    /// This is like doing `@f = 3` at the top level of a Ruby script.
    ///
    /// For a version that does not throw, see `RbObjectAccess.failable`.
    ///
    /// - parameter name: Name of IVar to set.  Must begin with a single '@'.
    /// - parameter newValue: New value to set.
    /// - returns: The value that was set.
    /// - throws: `RbError.badIdentifier` if `name` looks wrong.
    ///           `RbError.rubyException` if Ruby has a problem.
    @discardableResult
    public override func setInstanceVar(_ name: String, newValue: RbObjectConvertible) throws -> RbObject {
        try setup()
        try name.checkRubyInstanceVarName()
        let oldValue = try getGlobalVar(RbBridge.ivarWorkaroundName)
        try setGlobalVar(RbBridge.ivarWorkaroundName, newValue: newValue)
        defer { let _ = try? setGlobalVar(RbBridge.ivarWorkaroundName, newValue: oldValue) }
        return try eval(ruby: "\(name) = \(RbBridge.ivarWorkaroundName)")
        // TODO: simplify when we have hooked global vars...
    }
}

// MARK: - VM properties

extension RbBridge {
    /// Debug mode for Ruby code, sets `$DEBUG` / `$-d`.
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

    /// Verbosity setting for Ruby scripts - affects `Kernel#warn` etc.
    public enum Verbosity {
        /// Silent verbosity mode.
        case none
        /// Medium verbosity mode.  The Ruby default.
        case medium
        /// Full verbosity mode.
        case full
    }

    /// Verbose mode for Ruby code, sets `$VERBOSE` / `$-v`.
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

    /// Value of Ruby `$PROGRAM_NAME` / `$0`.
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

    /// The version number triple of Ruby being used, for example *2.5.0*.
    public var version: String {
        return String(cString: rbb_ruby_version())
    }

    /// The full version string for the Ruby being used.
    ///
    /// For example *ruby 2.5.0p0 (2017-12-25 revision 61468) [x86_64-darwin17]*.
    public var versionDescription: String {
        return String(cString: rbb_ruby_description())
    }
}

// MARK: - run code: eval, require, load

extension RbBridge {
    /// Evaluate some Ruby and return the result.
    ///
    /// - parameter ruby: Ruby code to execute at the top level.
    /// - returns: The result of executing the code.
    /// - throws: `RbError` if something goes wrong.
    public func eval(ruby: String) throws -> RbObject {
        try setup()
        return RbObject(rubyValue: try RbVM.doProtect {
            rb_eval_string_protect(ruby, nil)
        })
    }

    /// Load a Ruby file once-only.  See `Kernel#require`, but note this
    /// method is dispatched dynamically so it will invoke any replacements of
    /// `require`.
    ///
    /// - parameter filename: The name of the file to load.
    /// - returns: `true` if the file was loaded OK, `false` if it is already loaded.
    /// - throws: `RbError` if something goes wrong.  This usually means that Ruby
    ///           couldn't find the file.
    @discardableResult
    public func require(filename: String) throws -> Bool {
        // Have to use eval so that gems work - rubygems/kernel_require.rb replaces
        // `Kernel#require` so it can do the gem thing, so `rb_require` is no good.
        return try eval(ruby: "require '\(filename)'").isTruthy
    }

    /// See Ruby `Kernel#load`. Load a file, reloads if already loaded.
    ///
    /// - parameter filename: The name of the file to load
    /// - parameter wrap: If `true`, load the file into a fresh anonymous namespace
    ///   instead of the current program.  See `Kernel#load`.
    /// - throws: `RbError` if something goes wrong.
    public func load(filename: String, wrap: Bool = false) throws {
        try setup()
        return try RbObject(filename).withRubyValue { rubyValue in
            try RbVM.doProtect {
                rbb_load_protect(rubyValue, wrap ? 1 : 0, nil)
            }
        }
    }
}


// MARK: - Global declaration

/// The shared instance of `RbBridge`. :nodoc:
public let Ruby = RbBridge()
