//
//  TestVM.swift
//  RubyBridgeTests
//
//  Distributed under the MIT license, see LICENSE
//

import XCTest
@testable /* for raw RbVM and setup() access */ import RubyBridge

class TestVM: XCTestCase {
    /// Check we can bring up Ruby.
    func testInit() {
        do {
            try Ruby.setup()
        } catch {
            XCTFail("Ruby init failed, \(error)")
        }
    }

    /// Check whole thing is broadly functional
    func testEndToEnd() {
        do {
            let rc = try Ruby.require(filename: Helpers.fixturePath("backwards.rb"))
            XCTAssertTrue(rc)

            let string = "natural"

            let str = try Ruby.call("backwards", args: [string])

            XCTAssertEqual(String(string.reversed()), String(str))
        } catch {
            XCTFail("Unexpected exception, \(error)")
        }
    }

    /// Second init failure
    func testSecondInit() {
        testInit()

        let vm2 = RbVM()
        do {
            let _ = try vm2.setup()
            XCTFail("Unexpected pass of second init")
        } catch RbError.setup(_) {
            // OK
        } catch {
            XCTFail("Unexpected error type")
        }
    }

    /// 'require' works, path set up OK
    func testRequire() {
        do {
            let rc1 = try Ruby.require(filename: "pp") // Internal
            XCTAssertTrue(rc1)

            let rc2 = try Ruby.require(filename: "pp") // Internal, repeat
            XCTAssertFalse(rc2)

            let rc3 = try Ruby.require(filename: "minitest") // Gem shipped since 2.3ish
            XCTAssertTrue(rc3)
        } catch {
            XCTFail("Unexpected exception: \(error)")
        }

        do {
            let rc = try Ruby.require(filename: "not-ruby") // fail
            XCTFail("vm.require unexpectedly passed, rc=\(rc)")
        } catch {
            print("Got expected exception: \(error)")
        }
    }

    /// 'load' works
    func testLoad() {
        do {
            try Ruby.load(filename: Helpers.fixturePath("backwards.rb"))

            try Ruby.load(filename: Helpers.fixturePath("backwards.rb"))

            // TODO: need better test with some mutating state
        } catch {
            XCTFail("Unexpected exception: \(error)")
        }
    }

    func testLoadFailBadPath() {
        do {
            try Ruby.load(filename: "Should fail")
            XCTFail("Managed to load nonexistent file")
        } catch {
            // TODO: check sensible error
        }
    }

    func testLoadFailException() {
        do {
            try Ruby.load(filename: Helpers.fixturePath("unloadable.rb"))
            XCTFail("Managed to load unloadable file")
        } catch {
            // TODO: check sensible error
        }
    }

    /// debug flag
    func testDebug() {
        do {
            XCTAssertFalse(Ruby.debug)
            let debugVal1 = try Ruby.eval(ruby: "$DEBUG")
            XCTAssertFalse(debugVal1.isTruthy)

            Ruby.debug = true
            XCTAssertTrue(Ruby.debug)
            let debugVal2 = try Ruby.eval(ruby: "$DEBUG")
            XCTAssertTrue(debugVal2.isTruthy)

            Ruby.debug = false
            XCTAssertFalse(Ruby.debug)
        } catch {
            XCTFail("Unexpected exception: \(error)")
        }
    }

    /// verbose flag
    func testVerbose() {
        do {
            XCTAssertEqual(.medium, Ruby.verbose)
            let verboseVal1 = try Ruby.eval(ruby: "$VERBOSE")
            XCTAssertEqual(Qfalse, verboseVal1.rubyValue)

            Ruby.verbose = .full
            XCTAssertEqual(.full, Ruby.verbose)
            let verboseVal2 = try Ruby.eval(ruby: "$VERBOSE")
            XCTAssertEqual(Qtrue, verboseVal2.rubyValue)

            Ruby.verbose = .none
            XCTAssertEqual(.none, Ruby.verbose)
            let verboseVal3 = try Ruby.eval(ruby: "$VERBOSE")
            XCTAssertEqual(Qnil, verboseVal3.rubyValue)

            Ruby.verbose = .medium
            XCTAssertEqual(.medium, Ruby.verbose)
        } catch {
            XCTFail("Unexpected exception: \(error)")
        }
    }

    /// Script name
    func testScriptName() {
        let testTitle = "My title"
        Ruby.scriptName = testTitle

        XCTAssertEqual(testTitle, Ruby.scriptName)
    }

    /// Version
    func testVersion() {
        let version = Ruby.version
        let description = Ruby.versionDescription

        XCTAssertTrue(description.contains(version))
    }

    static var allTests = [
        ("testInit", testInit),
        ("testEndToEnd", testEndToEnd),
        ("testSecondInit", testSecondInit),
        ("testRequire", testRequire),
        ("testDebug", testDebug),
        ("testVerbose", testVerbose),
        ("testScriptName", testScriptName),
        ("testVersion", testVersion)
    ]
}
