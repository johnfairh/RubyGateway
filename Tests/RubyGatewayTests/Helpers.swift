//
//  VMWrapper.swift
//  RubyGatewayTests
//
//  Distributed under the MIT license, see LICENSE
//

import Foundation
import RubyGateway
import XCTest

extension XCTestCase {
    /// Standard wrapper for error checking
    func doErrorFree(call: () throws -> ())  {
        do {
            try call()
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    /// Standard wrapper for error checking
    func doErrorFree<T>(fallback: T, call: () throws -> T) -> T {
        do {
            return try call()
        } catch {
            XCTFail("Unexpected error: \(error)")
            return fallback
        }
    }

    /// Standard wrapper for expected errors
    func doError(call: () throws -> ()) {
        do {
            try call()
            // Shouldn't really get here, want more explicit fail in client
            XCTFail("No error thrown")
        } catch {
            print("Caught and swallowed \(error)")
        }
    }
}

/// Misc test helpers
struct Helpers {
    /// Ruby's lifetime rules mean that we can't create + tear down VMs willy-nilly as
    /// one would naturally do in a test environment.  So we set up a singleton here.
    ///
    /// To test that 'cleanup' actually works we will need a second test target (and hope
    /// that the test runner will treat that as a separate process.)

    /// Ruby files etc.
    private static let fixturesDir: String = {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().path + "/Fixtures"
    }()

    /// Get full path to fixture with name
    static func fixturePath(_ name: String) -> String {
        "\(fixturesDir)/\(name)"
    }

    /// A weird Swift type that has distinct Swift instances
    /// but identical Ruby instances.  Simulate some kind of client bug...
    struct ImpreciseRuby: RbObjectConvertible, Hashable {
        let val: Int

        init(_ val: Int) {
            self.val = val
        }

        init?(_ value: RbObject) {
            nil
        }

        var rubyObject: RbObject {
            RbObject(42)
        }
    }
}
