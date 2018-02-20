//
//  RbVM.swift
//  RubyBridge
//
//  Distributed under the MIT license, see LICENSE
//
// http://ruby-hacking-guide.github.io/gc.html
// http://blade.nagaokaut.ac.jp/cgi-bin/scat.rb/ruby/ruby-core/60741
// https://blog.heroku.com/incremental-gc

import Foundation
import CRuby
import RubyBridgeHelpers

/// An instance of a Ruby virtual machine.
open class RbVM {

    /// Has Ruby ever been initialized in this process?
    private static var initializedEver: Bool {
        return rb_mKernel != 0
    }

    /// Do we need to shut down Ruby?
    private var needCleanup: Bool

    /// Initialize the Ruby VM for this process.  The VM resources are freed up by `RbVM.cleanup()`
    /// or when there are no more refs to the `RbVM` object.
    ///
    /// There can only be one VM for a process.  This means that you cannot create a second `RbVM`
    /// instance, even if the first instance has been cleaned up.
    ///
    /// The loadpath (where `require` looks) is set to the `lib/ruby` directories adjacent to the
    /// `libruby` the program is linked against and `$RUBYLIB`.  Gems are enabled.
    ///
    /// - throws: `RbError.initError` if there is a problem starting Ruby.
    public init() throws {
        guard !RbVM.initializedEver else {
            throw RbError.initError("Can't initialize Ruby, already been done for this process.")
        }

        let setup_rc = ruby_setup()
        guard setup_rc == 0 else {
            throw RbError.initError("Can't initialize Ruby, ruby_setup() failed: \(setup_rc)")
        }
        needCleanup = true

        // Calling ruby_options() sets up the loadpath nicely and does the bootstrapping of
        // rubygems so they can be required directly.
        // The -e part is to prevent it reading from stdin - empty script.
        let arg1 = strdup("RubyBridge")
        let arg2 = strdup("-e ")
        defer {
            free(arg1)
            free(arg2)
        }
        var argv = [arg1, arg2]
        let node = ruby_options(Int32(argv.count), &argv)

        var exit_status: Int32 = 0
        let node_status = ruby_executable_node(node, &exit_status)
        // `node` is a compiled version of the empty Ruby program.  Which we, er, leak.  Ahem.
        // `node_status` should be TRUE (NOT Qtrue!) because `node` is a program and not an error code.
        // `exit_status` should be 0 because it should be unmodified given `node` is a program.
        guard node_status == 1 && exit_status == 0 else {
            cleanup()
            throw RbError.initError("Can't initialize Ruby, ruby_executable_node() gave node_status \(node_status) exit status \(exit_status)")
        }

        scriptName = "RubyBridge"
    }

    /// Shut down the Ruby VM and release resources.  From the Ruby API headers:
    ///
    /// This includes calling `END{}` code and procs registered by `Kernel.#at_exit`.
    ///
    /// - returns: 0 if all is well, otherwise some error code.
    @discardableResult
    public func cleanup() -> Int32 {
        guard needCleanup else {
            return 0;
        }
        defer { needCleanup = false }
        return ruby_cleanup(0)
    }

    deinit {
        cleanup()
    }

    /// Cache of rb_intern() calls.
    private static var idCache: [String: ID] = [:]
}

// MARK: - VM settings - debug, verbose, script name, version

extension RbVM {

    /// Debug mode for Ruby code, sets `$DEBUG` / `$-d`
    public var debug: Bool {
        get {
            guard let debug_ptr = rb_ruby_debug_ptr() else {
                // Current implementation can't fail but let's not crash.
                return false
            }
            return debug_ptr.pointee == Qtrue;
        }
        set {
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

    /// The version number triple of Ruby being used, eg. "2.5.0".
    public var version: String {
        return String(cString: rbb_ruby_version())
    }

    /// The full version string for the Ruby being used, eg. "ruby 2.5.0p0 (2017-12-25 revision 61468) [x86_64-darwin17]"
    public var versionDescription: String {
        return String(cString: rbb_ruby_description())
    }
}

// MARK: - run code: eval, require, load

extension RbVM {

    /// Evaluate some Ruby and return the result.
    /// XXX fix this up
    public func eval(ruby: String) throws -> VALUE {
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
    public func require(filename: String) throws -> Bool {
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

// MARK: - ID lookup

extension RbVM {

    /// Get an `ID` ready to call a method, for example.
    ///
    /// This is public for users to interop with `CRuby`, it is not
    /// needed for regular `RubyBridge` use.
    ///
    /// - parameter name: name to look up, typically constant or method name.
    /// - returns: the corresponding ID
    /// - throws: `RbException` if Ruby raises -- probably means the `ID` space
    ///   is full, which is fairly unlikely.
    public static func getID(from name: String) throws -> ID {
        if let rbId = idCache[name] {
            return rbId
        }
        var state = Int32(0)
        let rbId = rbb_intern_protect(name, &state)
        if state != 0 {
            let exception = rb_errinfo()
            defer { rb_set_errinfo(Qnil) }
            throw RbException(rubyValue: exception)
        }
        idCache[name] = rbId
        return rbId
    }
}

// MARK: - Constant access from an object

extension RbVM: RbConstantScope {
    var constantScopeValue: VALUE {
        return rb_cObject
    }
}
