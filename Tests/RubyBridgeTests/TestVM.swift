//
//  TestVM.swift
//  RubyBridgeTests
//
//  Distributed under the MIT license, see LICENSE
//

import XCTest
import CRuby
@testable import RubyBridge

class TestVM: XCTestCase {
    /// Check we can bring up Ruby.
    func testInit() {
        let _ = Helpers.ruby
    }

    /// Check whole thing is broadly functional
    func testEndToEnd() {
        let _ = Helpers.ruby
        rb_require(Helpers.fixturePath("backwards.rb"))
        let string = "natural"
        var stringArg = rb_str_new_cstr(string)
        var result = rb_funcallv(0, rb_intern("backwards"), 1, &(stringArg))
        let str = rb_string_value_cstr(&(result))

        XCTAssertEqual(String(string.reversed()), String(cString: str!))
    }

    /// Second init failure
    func testSecondInit() {
        let _ = Helpers.ruby

        do {
            let second = try RbVM()
            XCTFail("Should not have worked: \(second)")
        } catch RbError.initError(_) {
            // OK
        } catch {
            XCTFail("Unexpected error type")
        }
    }

    /// 'require' works, path set up OK
    func testRequire() {
        let vm = Helpers.ruby

        do {
            let rc1 = try vm.require(filename: "pp") // Internal
            XCTAssertTrue(rc1)

            let rc2 = try vm.require(filename: "pp") // Internal, repeat
            XCTAssertFalse(rc2)

            let rc3 = try vm.require(filename: "rouge") // Gem
            XCTAssertTrue(rc3)

            let rc4 = try vm.require(filename: "not-ruby") // fail
            XCTFail("vm.require unexpectedly passed, rc=\(rc4)")
        } catch {
            print("Got expected exception: \(error)")
        }
    }

    /// debug flag
    func testDebug() {
        let vm = Helpers.ruby

        do {
            XCTAssertFalse(vm.debug)
            let debugVal1 = try vm.eval(ruby: "$DEBUG")
            XCTAssertTrue(!RB_TEST(debugVal1))

            vm.debug = true
            XCTAssertTrue(vm.debug)
            let debugVal2 = try vm.eval(ruby: "$DEBUG")
            XCTAssertTrue(RB_TEST(debugVal2))

            vm.debug = false
            XCTAssertFalse(vm.debug)
        } catch {
            XCTFail("Unexpected exception: \(error)")
        }
    }

    /// verbose flag
    func testVerbose() {
        let vm = Helpers.ruby

        do {
            XCTAssertEqual(RbVM.Verbosity.medium, vm.verbose)
            let verboseVal1 = try vm.eval(ruby: "$VERBOSE")
            XCTAssertEqual(Qfalse, verboseVal1)

            vm.verbose = .full
            XCTAssertEqual(RbVM.Verbosity.full, vm.verbose)
            let verboseVal2 = try vm.eval(ruby: "$VERBOSE")
            XCTAssertEqual(Qtrue, verboseVal2)

            vm.verbose = .none
            XCTAssertEqual(RbVM.Verbosity.none, vm.verbose)
            let verboseVal3 = try vm.eval(ruby: "$VERBOSE")
            XCTAssertEqual(Qnil, verboseVal3)

            vm.verbose = .medium
            XCTAssertEqual(RbVM.Verbosity.medium, vm.verbose)
        } catch {
            XCTFail("Unexpected exception: \(error)")
        }
    }

    /// Script name
    func testScriptName() {
        let vm = Helpers.ruby
        let testTitle = "My title"
        vm.scriptName = testTitle

        // XXX fix me
        // XCTAssertEqual(testTitle, vm.scriptName)
    }

    /// Version
    func testVersion() {
        let vm = Helpers.ruby
        let version = vm.version
        let description = vm.versionDescription

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
