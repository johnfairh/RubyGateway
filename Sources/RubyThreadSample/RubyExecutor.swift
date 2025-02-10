//
//  RubyExecutor.swift
//  RubyThreadSample
//
//  Distributed under the MIT license, see LICENSE
//

import Foundation
import RubyGateway

/// A serial executor bound to its own thread.
///
/// Initializes Ruby on the thread and shuts it down (``RubyGateway.cleanup``) if the executor is stopped.
@available(macOS 14, *)
final class RubyExecutor: SerialExecutor, @unchecked Sendable {
    /// Combination mutex & CV protecting ``jobs`` and ``quit`` and ``thread``
    private let cond: NSCondition

    /// Swift concurrency work pending execution
    private var jobs: [UnownedJob]

    /// Interlocked state for ``stop()`.
    private enum Quit {
        case no
        case sent
        case done
    }
    private var quit: Quit

    // MARK: Lifecycle

    /// Create a new dedicated-thread executor
    ///
    /// - Parameters:
    ///   - qos: The ``QualityOfService`` for the executor's thread.
    ///   - name: A name for the executor's thread for debug.
    public init(qos: QualityOfService = .default, name: String = "RubyExecutor") {
        self.cond = NSCondition()
        self.jobs = []
        self.quit = .no
        self.qos = qos
        self.name = name
        self.cond.name = "\(name) CV"
        self._thread = nil

        Thread.detachNewThread { [unowned self] in
            Thread.current.qualityOfService = qos
            Thread.current.name = name
            thread = Thread.current
            threadMain()
            thread = nil
        }
    }

    /// Stop the executor.
    ///
    /// Blocks until the thread has finished any pending jobs and cleaned up Ruby.
    /// If any actors still exist associated with this then they will stop working in a bad way.
    ///
    /// It's not at all mandatory to call this - only if you are relying on Ruby's "graceful shutdown"
    /// path for some reason.
    public func stop() {
        cond.withLock {
            guard quit == .no else {
                return
            }
            quit = .sent
            cond.signal()

            while quit == .sent {
                cond.wait()
            }
        }
    }

    // MARK: Properties

    /// The `QualityOfService`used by the executor's thread
    public let qos: QualityOfService

    /// The (debug) name associated with the executor's thread and locks
    public let name: String

    private var _thread: Thread?

    /// The ``Thread`` for the executor, or ``nil`` if it's not running
    public private(set) var thread: Thread? {
        get {
            cond.withLock { _thread }
        }
        set {
            cond.withLock { _thread = newValue }
        }
    }

    private func threadMain() {
        _ = Ruby.softSetup()

        cond.lock()

        while quit == .no {
            if jobs.isEmpty {
                cond.wait()
            }

            let loopJobs = jobs
            jobs = []

            cond.unlock()

            for job in loopJobs {
                job.runSynchronously(on: asUnownedSerialExecutor())
            }

            cond.lock()
        }

        cond.unlock()
        _ = Ruby.cleanup()
        cond.lock()

        quit = .done
        cond.signal()

        cond.unlock()
    }

    /// Send a job to be executed later on the thread
    ///
    /// Called by the Swift runtime, do not call.  :nodoc:
    public func enqueue(_ job: consuming ExecutorJob) {
        let unownedJob = UnownedJob(job)
        cond.withLock {
            jobs.append(unownedJob)
            cond.signal()
        }
    }
}
