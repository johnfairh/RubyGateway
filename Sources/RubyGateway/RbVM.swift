//
//  RbVM.swift
//  RubyGateway
//
//  Distributed under the MIT license, see LICENSE

@preconcurrency internal import CRuby
internal import RubyGatewayHelpers

/// This class handles the setup and cleanup lifecycle events for the Ruby VM as well
/// as storing data associated with the Ruby runtime.
///
/// There can only be one of these for a process which is enforced by this class not
/// being public + `RbGateway` holding the only instance.
final class RbVM : @unchecked Sendable {
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
    private var state: State

    /// Cache of rb_intern() calls.
    private var idCache: [String: ID]

    /// Protect state (bit pointless given Ruby's state but feels bad not to)
    private var lock: Lock

    /// Set up data
    init() {
        state = .unknown
        idCache = [:]
        // Paranoid about reentrant symbol lookup during finalizers...
        lock = Lock(recursive: true)
    }

    /// Check the state of the VM, make it better if possible.
    /// Returning means Ruby is working; throwing something means it is not.
    /// - returns: `true` on the actual setup, `false` subsequently.
    func setup() throws -> Bool {
        try lock.locked {
            switch state {
            case .setupError(let error):
                throw error
            case .setup:
                return false
            case .cleanedUp:
                try RbError.raise(error: .setup("Ruby has already been cleaned up."))
            case .unknown:
                break
            }

            do {
                try doSetup()
                state = .setup
            } catch {
                state = .setupError(error)
                throw error
            }
            return true
        }
    }

    /// Shut down the Ruby VM and release resources.
    ///
    /// - returns: 0 if all is well, otherwise some error code.
    @discardableResult
    func cleanup() -> Int32 {
        lock.locked {
            guard case .setup = state else {
                return 0;
            }
            defer { state = .cleanedUp }
            return ruby_cleanup(0)
        }
    }

    /// Shut down Ruby at process exit if possible
    /// (Swift seems to not call this for static-scope objects so we don't get here
    /// ... there's a compensating atexit() in `RbGateway.setup()`.)
    deinit {
        cleanup()
    }

    /// Has Ruby ever been set up in this process?
    private var setupEver: Bool {
        rb_mKernel != 0
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
            try RbError.raise(error: .setup("Has already been done (via C API?) for this process."))
        }

        // What is going on with init_stack
        // --------------------------------
        // Line added for Ruby 3.4 because of ruby/ruby:9505 that took it out of `ruby_setup()`.
        //
        // This stack frame we're in now isn't very interesting except for defining the native thread
        // that will become the Ruby "main thread".  Here is why it's OK to call this macro:
        //
        // `RUBY_INIT_STACK` declares a ‘stack’ variable and calls `vm.c:ruby_init_stack()` which
        // stores that variable address in `native_main_thread_stack_top`, the only place that is set.
        //
        // `eval.c:ruby_setup()` -> `vm.c:Init_BareVM()` is the only place that refers to the static
        // and passes to `thread.c:ruby_thread_init_stack()` for the current thread, which for platforms
        // we care about[1] leads to `thread_pthread.c:native_thread_init_stack()`.  We only care about the
        // “main thread” use-case at this point and go to`thread_pthread.c:native_thread_init_main_thread_stack()`.
        // We only care about `MAINSTACKADDR_AVAILABLE` and so do not use the address to figure the
        // stack layout for GC.  Then there is a sanity check which is the only place the address is
        // used - as long as it is within the stack as reported by pthreads then we are good.
        //
        // [1] Brief eyeball the win32 version looks OK too.
        //
        rbg_RUBY_INIT_STACK()

        let setup_rc = ruby_setup()
        guard setup_rc == 0 else {
            try RbError.raise(error: .setup("ruby_setup() failed: \(setup_rc)"))
        }

        // Calling ruby_options() sets up the loadpath nicely and does the bootstrapping of
        // rubygems so they can be required directly.
        // The -e part is to prevent it reading from stdin - empty script.
        let arg1 = strdup("RubyGateway")
        let arg2 = strdup("-e ")
        defer {
            arg1.map { free($0) }
            arg2.map { free($0) }
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
            try RbError.raise(error: .setup("ruby_executable_node() gave node_status \(node_status) exit status \(exit_status)"))
        }
    }

    /// Test hook to fake out 'setup error' state.
    func utSetSetupError() {
        let error = RbError.setup("Unit test setup failure")
        RbError.history.record(error: error)
        state = .setupError(error)
    }

    /// Test hook to fake out 'cleaned up' state.
    func utSetCleanedUp() {
        state = .cleanedUp
    }

    /// Test hook to get back to normal.
    func utSetSetup() {
        state = .setup
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
        try lock.locked {
            if let rbId = idCache[name] {
                return rbId
            }
            let rbId = try RbVM.doProtect { tag in
                rbg_intern_protect(name, &tag)
            }
            idCache[name] = rbId
            return rbId
        }
    }

    /// Helper to call a protected Ruby API function and propagate any Ruby exception
    /// or unusual flow control as a Swift `RbException`.
    static func doProtect<T>(call: (inout Int32) -> T) throws -> T {
        var tag = Int32(0)
        let result = call(&tag)

        let errorObj = RbObject(rubyValue: rb_errinfo())
        guard !errorObj.isNil else {
            return result
        }

        switch errorObj.rubyType {
        case .T_OBJECT:
            // Normal case, a Ruby exception
            rb_set_errinfo(Qnil)
            try RbError.raise(error: .rubyException(RbException(exception: errorObj)))
        default:
            // Probably T_IMEMO for throw/break/return/etc.
            try RbError.raise(error: .rubyJump(tag))
        }
    }
}
