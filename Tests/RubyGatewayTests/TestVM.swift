//
//  TestVM.swift
//  RubyGatewayTests
//
//  Distributed under the MIT license, see LICENSE
//

import XCTest
@testable /* for raw RbVM and setup() access */ import RubyGateway

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
            let _ = try Ruby.require(filename: Helpers.fixturePath("endtoend.rb"))

            let ver = 1.2
            let name = "fred"

            guard let obj = RbObject(ofClass: "RubyGateway::EndToEnd", args: [ver], kwArgs: [("name", name)]) else {
                XCTFail("Couldn't create object")
                return
            }

            try XCTAssertEqual(ver, Double(obj.get("version")))
            try XCTAssertEqual(name, String(obj.get("name")))
            XCTAssertEqual("\(name) (version \(ver))", obj.description)
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

            let rc3 = try Ruby.require(filename: "rdoc") // Gem shipped apparently everywhere??
            XCTAssertTrue(rc3)
        } catch {
            XCTFail("Unexpected exception: \(error)")
        }

        do {
            let rc = try Ruby.require(filename: "not-ruby") // fail
            XCTFail("vm.require unexpectedly passed, rc=\(rc)")
        } catch RbError.rubyException(let exn) {
            XCTAssertTrue(exn.description.contains("LoadError: cannot load such file"))
        } catch {
            XCTFail("Unexpected exception: \(error)")
        }
    }

    /// 'load' works
    func testLoad() {
        do {
            // load wrapped version - no access
            try Ruby.load(filename: Helpers.fixturePath("backwards.rb"), wrap: true)

            let str = "forwards"

            do {
                let rc = try Ruby.call("backwards", args: [str])
                XCTFail("Managed to resolve backwards global: \(rc)")
            } catch {
            }

            // now load unwrapped
            try Ruby.load(filename: Helpers.fixturePath("backwards.rb"), wrap: false)

            let rc = try Ruby.call("backwards", args: [str])
            XCTAssertEqual(String(str.reversed()), String(rc))

        } catch {
            XCTFail("Unexpected exception: \(error)")
        }
    }

    func testLoadFailBadPath() {
        do {
            try Ruby.load(filename: "Should fail")
            XCTFail("Managed to load nonexistent file")
        } catch RbError.rubyException(let exn) {
            XCTAssertTrue(exn.description.contains("LoadError: cannot load such file"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testLoadFailException() {
        do {
            try Ruby.load(filename: Helpers.fixturePath("unloadable.rb"))
            XCTFail("Managed to load unloadable file")
        } catch RbError.rubyException(let exn) {
            XCTAssertTrue(exn.description.contains("SyntaxError:"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    /// debug flag
    func testDebug() {
        do {
            XCTAssertFalse(Ruby.debug)
            let debugVal1 = try Ruby.getGlobalVar("$DEBUG")
            XCTAssertFalse(debugVal1.isTruthy)

            Ruby.debug = true
            XCTAssertTrue(Ruby.debug)
            let debugVal2 = try Ruby.getGlobalVar("$DEBUG")
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
            let verboseVal1 = try Ruby.getGlobalVar("$VERBOSE")
            XCTAssertFalse(Bool(verboseVal1)!)

            Ruby.verbose = .full
            XCTAssertEqual(.full, Ruby.verbose)
            let verboseVal2 = try Ruby.getGlobalVar("$VERBOSE")
            XCTAssertTrue(Bool(verboseVal2)!)

            Ruby.verbose = .none
            XCTAssertEqual(.none, Ruby.verbose)
            let verboseVal3 = try Ruby.getGlobalVar("$VERBOSE")
            XCTAssertTrue(verboseVal3.isNil)

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
        let (mj, mn, _) = Ruby.apiVersion

        XCTAssertTrue(description.contains(version))
        XCTAssertEqual(2, mj)
        XCTAssertTrue(version.starts(with: "\(mj).\(mn)"))
    }

    /// Setup failure
    func testSetupFailures() {
        try! Ruby.setup()

        RbGateway.vm.utSetSetupError()
        defer { RbGateway.vm.utSetSetup() }

        // explicit setup() call fails
        do {
            try Ruby.setup()
            XCTFail("Unexpected setup OK in setupError")
        } catch {
        }

        // API call doesn't make it to Ruby
        // (could be a lot more exhaustive...)
        do {
            let ret = try Ruby.eval(ruby: "exit!")
            XCTFail("Unexpected exit pass in setupError - \(ret)")
        } catch {
        }

        // scriptname fail-safe
        XCTAssertEqual("", Ruby.scriptName)

        // verbose fail-safe
        XCTAssertEqual(.none, Ruby.verbose)
        Ruby.verbose = .full  // swallowed
        XCTAssertEqual(.none, Ruby.verbose)

        // debug fail-safe
        XCTAssertFalse(Ruby.debug)
        Ruby.debug = true // swallowed
        XCTAssertFalse(Ruby.debug)

        // type construction fails out safely
        let strObj: RbObject = "test"
        let uintObj = RbObject(UInt(200))
        let intObj: RbObject = -200
        let dblObj: RbObject = 100.2
        let symObj = RbObject(RbSymbol("test"))
        let procObj = RbObject() { args in .nilObject }
        let arrObj: RbObject = [1,2,3]
        let hashObj: RbObject = [1: 2]

        [strObj, uintObj, intObj, dblObj, symObj, procObj, arrObj, hashObj].forEach { obj in
            XCTAssertTrue(obj.isNil)
        }
    }

    /// Cleaned-up state
    func testCleanedUpFailure() {
        try! Ruby.setup()

        RbGateway.vm.utSetCleanedUp()
        defer { RbGateway.vm.utSetSetup() }

        // explicit setup() call fails
        do {
            try Ruby.setup()
            XCTFail("Unexpected setup OK in setupError")
        } catch {
        }
    }

    static var allTests = [
        ("testInit", testInit),
        ("testEndToEnd", testEndToEnd),
        ("testSecondInit", testSecondInit),
        ("testRequire", testRequire),
        ("testLoad", testLoad),
        ("testLoadFailBadPath", testLoadFailBadPath),
        ("testLoadFailException", testLoadFailException),
        ("testDebug", testDebug),
        ("testVerbose", testVerbose),
        ("testScriptName", testScriptName),
        ("testVersion", testVersion),
        ("testSetupFailures", testSetupFailures),
        ("testCleanedUpFailure", testCleanedUpFailure)
    ]
}
