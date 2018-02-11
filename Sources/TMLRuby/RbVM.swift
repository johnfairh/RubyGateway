//
//  RbVM.swift
//  TMLRuby
//
//  Created by John Fairhurst on 12/02/2018.
//

import Foundation
import CRuby

// 3. test for load path
// verbose / warning level
// 4. require
// 5. eval
// 5. exception catching vs. require OMG


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
        let arg1 = strdup("TMLRuby")
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
        // `node_status` should be TRUE because `node` is a program and not an error code.
        // `exit_status` should be 0 because it should be unmodified given `node` is a program.
        guard node_status == 1 && exit_status == 0 else {
            cleanup()
            throw RbError.initError("Can't initialize Ruby, ruby_executable_node() gave node_status \(node_status) exit status \(exit_status)")
        }
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
}
