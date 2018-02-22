//
//  RbVM.swift
//  RubyBridge
//
//  Distributed under the MIT license, see LICENSE
//
// http://ruby-hacking-guide.github.io/gc.html
// http://blade.nagaokaut.ac.jp/cgi-bin/scat.rb/ruby/ruby-core/60741
// https://blog.heroku.com/incremental-gc

import CRuby
import RubyBridgeHelpers

/// This class handles the setup and cleanup lifecycle events for the Ruby VM as well
/// as storing data associated with the Ruby runtime.
///
/// There can only be one of these for a process which is enforced by this class not
/// being public + `RbBridge` holding the only instance.
final class RbVM {

    /// State of Ruby lifecycle
    private enum State {
        /// Never tried
        case unknown
        /// Tried to set up, failed with something
        case setupError(Error)
        /// Set up OK
        case setup
        /// Cleaned up, can't be used
        case cleanedUp
    }
    /// Current state of the VM
    private var state = State.unknown

    /// Cache of rb_intern() calls.
    private var idCache: [String: ID] = [:]

    /// Protect state (bit pointless given Ruby's state but feels bad not to)
    private var mutex = pthread_mutex_t()

    /// Set up data
    init() {
        state = .unknown
        idCache = [:]

        // Paranoid about reentrant symbol lookup during finalizers...
        var attr = pthread_mutexattr_t()
        pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE)
        pthread_mutex_init(&mutex, &attr)
    }

    private func lock()   { pthread_mutex_lock(&mutex) }
    private func unlock() { pthread_mutex_unlock(&mutex) }

    /// Check the state of the VM, make it better if possible.
    /// Returning means Ruby is working; throwing something means it is not.
    /// - returns: `true` on the actual setup, `false` subsequently.
    func setup() throws -> Bool {
        lock(); defer { unlock() }

        switch state {
        case .setupError(let error):
            throw error
        case .setup:
            return false
        case .cleanedUp:
            throw RbError.setup("Can't set up Ruby, has already been cleaned up.")
        case .unknown:
            break
        }

        do {
            try doSetup()
            state = .setup
            return true
        } catch {
            state = .setupError(error)
            throw error
        }
    }

    /// Shut down the Ruby VM and release resources.
    ///
    /// - returns: 0 if all is well, otherwise some error code.
    @discardableResult
    func cleanup() -> Int32 {
        lock(); defer { unlock() }

        guard case .setup = state else {
            return 0;
        }
        defer { state = .cleanedUp }
        return ruby_cleanup(0)
    }

    /// Shut down Ruby at process exit if possible
    /// (Swift seems to not call this for static-scope objects so we don't get here
    /// ... there's a compensating atexit() in `RbBridge.setup()`.)
    deinit {
        cleanup()
    }

    /// Has Ruby ever been set up in this process?
    private var setupEver: Bool {
        return rb_mKernel != 0
    }

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
    private func doSetup() throws {
        guard !setupEver else {
            throw RbError.setup("Can't set up Ruby, already been done for this process.")
        }

        let setup_rc = ruby_setup()
        guard setup_rc == 0 else {
            throw RbError.setup("Can't set up Ruby, ruby_setup() failed: \(setup_rc)")
        }

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
            ruby_cleanup(0)
            throw RbError.setup("Can't set up Ruby, ruby_executable_node() gave node_status \(node_status) exit status \(exit_status)")
        }
    }

    /// Get an `ID` ready to call a method, for example.
    ///
    /// Cache this on the Swift side.
    ///
    /// - parameter name: name to look up, typically constant or method name.
    /// - returns: the corresponding ID
    /// - throws: `RbException` if Ruby raises -- probably means the `ID` space
    ///   is full, which is fairly unlikely.
    func getID(for name: String) throws -> ID {
        lock(); defer { unlock() }

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
