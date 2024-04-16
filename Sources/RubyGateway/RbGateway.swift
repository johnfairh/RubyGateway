//
//  RbGateway.swift
//  RubyGateway
//
//  Distributed under the MIT license, see LICENSE
//
@preconcurrency internal import CRuby
internal import RubyGatewayHelpers

/// Provides top-level Ruby services: information about the Ruby VM, evaluate
/// expressions, access various kinds of Ruby objects, and define new Ruby
/// classes, modules, and functions.
///
/// You cannot instantiate this type.  Instead RubyGateway exports a public
/// instance `Ruby`.  Among other things this permits a dynamic member lookup
/// programming style.
///
/// The Ruby VM is initialized when the object is first accessed and is
/// automatically stopped when the process ends.  The VM can be manually shut
/// down before process exit by calling `RbGateway.cleanup()` but once this has
/// been done the VM cannot be restarted and subsequent calls to RubyGateway
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
/// import RubyGateway
///
/// print("Ruby version is \(Ruby.version)")
///
/// do {
///    try Ruby.require(filename: "rouge")
///    let html = try Ruby.get("Rouge").call("highlight", args: ["let a = 1", "swift", "html"])
/// } catch {
/// }
/// ```
///
/// If you just want to create a Ruby object of some class, see
/// `RbObject.init(ofClass:args:kwArgs:)`.
///
/// ## Running Ruby code
///
/// Use `RbGateway.eval(ruby:)` to evaulate a Ruby expression in the current VM.
/// For example:
/// ```swift
/// let result = try Ruby.eval(ruby: "Rouge.highlight('let a = 1', 'swift', 'html')")
/// ```
///
/// ## Defining new Ruby classes
///
/// Use `RbGateway.defineClass(_:parent:under:)` and `RbGateway.defineModule(_:under:)`
/// to define new classes and modules.  Then add methods using `RbObject.defineMethod(...)`
/// and `RbObject.defineSingletonMethod(...)`.
///
public final class RbGateway: RbObjectAccess, @unchecked Sendable {

    /// The VM - not initialized until `setup()` is called.
    static let vm = RbVM()

    init() {
        super.init(getValue: { rb_cObject })
    }

    /// Initialize Ruby.  Throw an error if Ruby is not working.
    /// Called by anything that might by the first op.
    func setup() throws {
        if try RbGateway.vm.setup() {
            try! require(filename: "set")
            // Work around Swift not calling static deinit...
            atexit { RbGateway.vm.cleanup() }
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
        RbGateway.vm.cleanup()
    }

    /// Get an `ID` ready to call a method, for example.
    ///
    /// This is public to permit interop with `CRuby`.  It is not
    /// needed for regular RubyGateway use.
    ///
    /// - parameter name: Name to look up, typically constant or method name.
    /// - returns: The corresponding ID.
    /// - throws: `RbError.rubyException(_:)` if Ruby raises an exception.  This
    ///   probably means the `ID` space is full, which is fairly unlikely.
    public func getID(for name: String) throws -> RbObject.VALUE {
        try RbGateway.vm.getID(for: name)
    }

    /// Attempt to initialize Ruby but swallow any error.
    ///
    /// This is for use from places that could be the first use of Ruby but it
    /// is not practical to throw an exception for API or aesthetic reasons.
    ///
    /// The idea is that callers can get by long enough for the user to call
    /// `require()` or `send()` which will properly report the VM setup error.
    ///
    /// This is public to let you implement `RbObjectConvertible.rubyObject` for
    /// custom types.  It is not required for regular RubyGateway use.
    public func softSetup() -> Bool {
        if let _ = try? setup() {
            return true
        }
        return false
    }

    // MARK: - Top Self Instance Variables

    // Can't put this lot in an extension because overrides....

    // Instance variables at the top level are associated with the 'top' object
    // that is unfortunately hidden from the public API (`rb_vm_top_self()`).  So
    // we have to use `eval` these.  Reading is easy enough; writing an arbitrary
    // VALUE is impossible to do without shenanigans.

    /// Get the value of a top-level instance variable.  Creates a new one with a `nil`
    /// value if it doesn't exist yet.
    ///
    /// This is like doing `@f` at the top level of a Ruby script.
    ///
    /// For a version that does not throw, see `RbObjectAccess.failable`.
    ///
    /// - parameter name: Name of IVar to get.  Must begin with a single '@'.
    /// - returns: Value of the IVar or Ruby `nil` if it has not been assigned yet.
    /// - throws: `RbError.badIdentifier(type:id:)` if `name` looks wrong.
    ///           `RbError.rubyException(_:)` if Ruby has a problem.
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
    /// - throws: `RbError.badIdentifier(type:id:)` if `name` looks wrong.
    ///           `RbError.rubyException(_:)` if Ruby has a problem.
    @discardableResult
    public override func setInstanceVar(_ name: String, newValue: (any RbObjectConvertible)?) throws -> RbObject {
        try setup()
        try name.checkRubyInstanceVarName()

        let ivarWorkaroundName = "$RbGatewayTopSelfIvarWorkaround"
        try defineGlobalVar(ivarWorkaroundName, get: { newValue.rubyObject })
        return try eval(ruby: "\(name) = \(ivarWorkaroundName)")
    }
}

// MARK: - VM Properties

extension RbGateway {
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
        get {
            // sigh
            guard softSetup(),
                let nameObj = try? getGlobalVar("$PROGRAM_NAME"),
                let name = String(nameObj) else {
                return ""
            }
            return name
        }
        set {
            if softSetup() {
                ruby_script(newValue)
            }
        }
    }

    /// The component major/minor/teeny version numbers of Ruby being used.
    public var apiVersion: (Int32, Int32, Int32) {
        ruby_api_version
    }

    /// The version number triple of Ruby being used, for example *2.5.0*.
    public var version: String {
        String(cString: rbg_ruby_version())
    }

    /// The full version string for the Ruby being used.
    ///
    /// For example *ruby 2.5.0p0 (2017-12-25 revision 61468) [x86_64-darwin17]*.
    public var versionDescription: String {
        String(cString: rbg_ruby_description())
    }

    /// Set the program arguments for the Ruby VM.
    ///
    /// Updates the `ARGV` constant.
    ///
    /// - parameter newArgv: The strings to make up the new version of `ARGV`.
    /// - throws: Various `RbError`s if the arguments can't be set.
    public func setArguments(_ newArgv: [String]) throws {
        try setup()

        // Don't actually assign the ARGV object to avoid warnings about modifying constants
        let rubyArgv = try get("ARGV")
        try rubyArgv.call("clear")
        try rubyArgv.call("concat", args: [newArgv])
    }
}

// MARK: - Ruby Code Execution

extension RbGateway {
    /// Evaluate some Ruby and return the result.
    ///
    /// - parameter ruby: Ruby code to execute at the top level.
    /// - returns: The result of executing the code.
    /// - throws: `RbError` if something goes wrong.
    /// - note: This is a lower level than `Kernel#eval` and less flexible - if you
    ///   need that function then access it via `RbGateway.call("eval")`.
    ///   Don't be tempted by `rb_eval_string_wrap()`, it is broken. #10466.
    @discardableResult
    public func eval(ruby: String) throws -> RbObject {
        try setup()
        return RbObject(rubyValue: try RbVM.doProtect { tag in
            rb_eval_string_protect(ruby, &tag)
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
        try eval(ruby: "require '\(filename)'").isTruthy
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
            try RbVM.doProtect { tag in
                rbg_load_protect(rubyValue, wrap ? 1 : 0, &tag)
            }
        }
    }
}

// MARK: - Global declaration

/// The shared instance of `RbGateway`. :nodoc:
public let Ruby = RbGateway()
