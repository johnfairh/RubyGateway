//
//  RbThread.swift
//  RubyGateway
//
//  Distributed under the MIT license, see LICENSE
//
@_implementationOnly import CRuby
@_implementationOnly import RubyGatewayHelpers

/// Context passed to thread callbacks wrapping up a Swift closure.
internal final class RbThreadContext {
    let callback: () -> Void

    init(_ callback: @escaping () -> Void) {
        self.callback = callback
    }

    /// Call a function passing it a `void *` representation of the `RbThreadContext`
    func withRaw(rawCallback: (UnsafeMutableRawPointer) -> Void) {
        let unmanaged = Unmanaged.passRetained(self)
        defer { unmanaged.release() }
        rawCallback(unmanaged.toOpaque())
    }

    /// Retrieve an `RbThreadContext` from its `void *` representation
    static func from(raw: UnsafeMutableRawPointer) -> RbThreadContext {
        Unmanaged<RbThreadContext>.fromOpaque(raw).takeUnretainedValue()
    }
}

private func rbthread_callback(rawContext: UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer? {
    let context = RbThreadContext.from(raw: rawContext!)
    context.callback()
    return nil
}

private func rbthread_ubf_callback(rawContext: UnsafeMutableRawPointer?) -> Void {
    let context = RbThreadContext.from(raw: rawContext!)
    context.callback()
}

/// This type provides a namespace for working with Ruby threads.
///
/// You cannot call Ruby on arbitrary threads: only the very first thread
/// where RubyGateway gets used or threads created by Ruby's `Thread` class.
///
/// There is no way to 'attach' the Ruby runtime to a thread created by client
/// code (eg. one accessed via libdispatch).
///
/// Even when multiple Ruby threads are active, the VM executes just one at a
/// time under control of a single lock known as the GVL.  The GVL is given up
/// over Ruby blocking operations and can be manually relinquished using
/// `RbThread.callWithoutGvl(callback:)`.
///
/// Inside a block that has given up the GVL, you must not call any Ruby code or
/// it will at best crash.  You can execute some code inside your GVL-free scope
/// that is allowed to call Ruby using `RbThread.callWithGvl(callback:)`.
public enum RbThread {
    /// Create a Ruby thread.
    ///
    /// This is a simple wrapper around creating a Ruby `Thread` object.
    ///
    /// - note: You must retain the returned `RbObject` until the Ruby thread
    ///         has finished to ensure the Swift callback is not released
    ///         prematurely.
    /// - parameter callback: Callback to make on the new thread
    /// - returns: The Ruby `Thread` object, or `nil` if there was a problem.
    ///            See `RbError.history` for details of any error.
    public static func create(callback: @Sendable @escaping () -> Void) -> RbObject? {
        RbObject(ofClass: "Thread", retainBlock: true) { args in
            callback()
            return .nilObject
        }
    }

    /// Does the Ruby VM know about the current thread?
    ///
    /// - returns: `true` if this is the main thread or another created by Ruby
    ///            where it's OK to call Ruby functions.
    public static func isRubyThread() -> Bool {
        ruby_native_thread_p() != 0
    }

    /// From a Ruby thread, run some non-Ruby code without the GVL.
    ///
    /// This allows other Ruby threads to run.  See the Ruby source code
    /// for lengthy comments about how to do this safely.
    ///
    /// Using this API ends up with no unblocking function for the section.
    /// See `callWithoutGvl(unblocking:callback:)` to configure that.
    public static func callWithoutGvl(callback: () -> Void) {
        withoutActuallyEscaping(callback) { escapingCallback in
            let context = RbThreadContext(escapingCallback)
            context.withRaw { rawContext in
                rb_thread_call_without_gvl(rbthread_callback, rawContext, nil, nil)
            }
        }
    }

    /// A way to unblock a thread executing inside a `callWithoutGvl` section.
    public enum UnblockingFunc {
        /// Same as `RUBY_UBF_IO`
        ///
        /// For pthread platforms, sends `SIGVTALRM` to the thread until it wakes up.
        case io

        /// A custom unblocking function.
        ///
        /// See Ruby thread.c if in any doubt.
        case custom(() -> Void)
    }

    /// From a Ruby thread, run some non-Ruby code without the GVL.
    ///
    /// This allows other Ruby threads to run.  See the Ruby source code
    /// for lengthy comments about how to do this safely.
    ///
    /// This version of the API takes an unblocking function to be used when
    /// Ruby wants to interrupt the thread and get it back under GVL control.
    public static func callWithoutGvl(unblocking: UnblockingFunc, callback: () -> Void) {
        withoutActuallyEscaping(callback) { escapingCallback in
            let context = RbThreadContext(escapingCallback)
            context.withRaw { rawContext in
                switch unblocking {
                case .custom(let ubfFunc):
                    withoutActuallyEscaping(ubfFunc) { escapingUbfFunc in
                        let ubfContext = RbThreadContext(escapingUbfFunc)
                        ubfContext.withRaw { rawUbfContext in
                            rb_thread_call_without_gvl(rbthread_callback, rawContext,
                                                       rbthread_ubf_callback, rawUbfContext)
                        }
                    }
                case .io:
                    rb_thread_call_without_gvl(rbthread_callback, rawContext, rbg_RUBY_UBF_IO(), nil)
                }
            }
        }
    }

    /// From a GVL-free section of code on a Ruby thread, reacquire the GVL and run some code.
    ///
    /// This cannot be used to attach a native thread to Ruby.  It should only be used
    /// from within the `callback` passed to `callWithoutGvl(callback:)`.  See the Ruby
    /// source code for more commentary.
    public static func callWithGvl(callback: () -> Void) {
        withoutActuallyEscaping(callback) { escapingCallback in
            let context = RbThreadContext(escapingCallback)
            context.withRaw { rawContext in
                rb_thread_call_with_gvl(rbthread_callback, rawContext)
            }
        }
    }
}
