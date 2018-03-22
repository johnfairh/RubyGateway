//
//  Lock.swift
//  RubyGateway
//
//  Distributed under the MIT license, see LICENSE
//

import Foundation

/// Dumb pthread wrapper.  Ostrich approach to error handling.
final class Lock {
    private var mutex = pthread_mutex_t()

    init(recursive: Bool = false) {
        if recursive {
            var attr = pthread_mutexattr_t()
            pthread_mutexattr_settype(&attr, Int32(PTHREAD_MUTEX_RECURSIVE))
            pthread_mutex_init(&mutex, &attr)
        } else {
            pthread_mutex_init(&mutex, nil)
        }
    }

    func lock() {
        pthread_mutex_lock(&mutex)
    }

    func unlock() {
        pthread_mutex_unlock(&mutex)
    }

    func locked<T>(call: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try call()
    }
}
