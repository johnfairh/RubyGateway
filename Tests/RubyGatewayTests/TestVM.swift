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
        doErrorFree {
            try Ruby.setup()
        }
    }

    /// Check whole thing is broadly functional
    func testEndToEnd() {
        doErrorFree {
            let _ = try Ruby.require(filename: Helpers.fixturePath("endtoend.rb"))

            let ver = 1.2
            let name = "fred"

            guard let obj = RbObject(ofClass: "RubyGateway::EndToEnd", args: [ver], kwArgs: ["name": name]) else {
                XCTFail("Couldn't create object")
                return
            }

            try XCTAssertEqual(ver, Double(obj.get("version")))
            try XCTAssertEqual(name, String(obj.get("name")))
            XCTAssertEqual("\(name) (version \(ver))", obj.description)
        }
    }

    /// Second init failure
    func testSecondInit() {
        testInit()

        let vm2 = RbVM()
        doErrorFree {
            do {
                let _ = try vm2.setup()
                XCTFail("Unexpected pass of second init")
            } catch RbError.setup(_) {
                // OK
            }
        }
    }

    /// 'require' works, path set up OK
    func testRequire() {
        doErrorFree {
            let rc1 = try Ruby.require(filename: "pp") // Internal
            XCTAssertTrue(rc1)

            let rc2 = try Ruby.require(filename: "pp") // Internal, repeat
            XCTAssertFalse(rc2)

            let rc3 = try Ruby.require(filename: "rdoc") // Gem shipped apparently everywhere??
            XCTAssertTrue(rc3)
        }

        doErrorFree {
            do {
                let rc = try Ruby.require(filename: "not-ruby") // fail
                XCTFail("vm.require unexpectedly passed, rc=\(rc)")
            } catch RbError.rubyException(let exn) {
                XCTAssertTrue(exn.description.contains("LoadError: cannot load such file"))
            }
        }
    }

    /// 'load' works
    func testLoad() {
        doErrorFree {
            // load wrapped version - no access
            try Ruby.load(filename: Helpers.fixturePath("backwards.rb"), wrap: true)

            let str = "forwards"

            doError {
                let rc = try Ruby.call("backwards", args: [str])
                XCTFail("Managed to resolve backwards global: \(rc)")
            }

            // now load unwrapped
            try Ruby.load(filename: Helpers.fixturePath("backwards.rb"), wrap: false)

            let rc = try Ruby.call("backwards", args: [str])
            XCTAssertEqual(String(str.reversed()), String(rc))
        }
    }

    func testLoadFailBadPath() {
        doErrorFree {
            do {
                try Ruby.load(filename: "Should fail")
                XCTFail("Managed to load nonexistent file")
            } catch RbError.rubyException(let exn) {
                XCTAssertTrue(exn.description.contains("LoadError: cannot load such file"))
            }
        }
    }

    func testLoadFailException() {
        doErrorFree {
            do {
                try Ruby.load(filename: Helpers.fixturePath("unloadable.rb"))
                XCTFail("Managed to load unloadable file")
            } catch RbError.rubyException(let exn) {
                let desc = exn.description
                XCTAssertTrue(desc.hasPrefix("SyntaxError:") || desc.hasPrefix("NameError:"))
            }
        }
    }

    /// debug flag
    func testDebug() {
        doErrorFree {
            XCTAssertFalse(Ruby.debug)
            let debugVal1 = try Ruby.getGlobalVar("$DEBUG")
            XCTAssertFalse(debugVal1.isTruthy)

            Ruby.debug = true
            XCTAssertTrue(Ruby.debug)
            let debugVal2 = try Ruby.getGlobalVar("$DEBUG")
            XCTAssertTrue(debugVal2.isTruthy)

            Ruby.debug = false
            XCTAssertFalse(Ruby.debug)
        }
    }

    /// verbose flag
    func testVerbose() {
        doErrorFree {
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
        XCTAssertTrue([2,3].contains(mj))
        XCTAssertTrue(version.starts(with: "\(mj).\(mn)"))
    }

    /// Setup failure
    func testSetupFailures() {
        try! Ruby.setup()

        RbGateway.vm.utSetSetupError()
        defer { RbGateway.vm.utSetSetup() }

        // explicit setup() call fails
        doError {
            try Ruby.setup()
            XCTFail("Unexpected setup OK in setupError")
        }

        // API call doesn't make it to Ruby
        // (could be a lot more exhaustive...)
        doError {
            let ret = try Ruby.eval(ruby: "exit!")
            XCTFail("Unexpected exit pass in setupError - \(ret)")
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

        // SAFE fail-safe
//        XCTAssertFalse(Ruby.taintChecks)
//        Ruby.taintChecks = true // swallowed
//        XCTAssertFalse(Ruby.taintChecks)

        // type construction fails out safely
        let strObj: RbObject = "test"
        let uintObj = RbObject(UInt(200))
        let intObj: RbObject = -200
        let dblObj: RbObject = 100.2
        let symObj = RbObject(RbSymbol("test"))
        let procObj = RbObject() { args in .nilObject }
        let arrObj: RbObject = [1,2,3]
        let hashObj: RbObject = [1: 2]
        let rangeObj = RbObject(1...3)
        let setObj = RbObject(Set<Int>())
        let sliceObj = RbObject([1,2,3][1..<2])
        let complexObj = RbObject(RbComplex(real: 1, imaginary: 1))
        let rationalObj = RbObject(RbRational(numerator: 1, denominator: 1))

        [strObj, uintObj, intObj, dblObj, symObj,
         procObj, arrObj, hashObj, rangeObj, setObj,
         sliceObj, complexObj, rationalObj].forEach { obj in
            XCTAssertTrue(obj.isNil)
        }
    }

    /// Cleaned-up state
    func testCleanedUpFailure() {
        try! Ruby.setup()

        RbGateway.vm.utSetCleanedUp()
        defer { RbGateway.vm.utSetSetup() }

        // explicit setup() call fails
        doError {
            try Ruby.setup()
            XCTFail("Unexpected setup OK in setupError")
        }
    }

    /// ARGV
    func testArgv() {
        doErrorFree {
            let rubyArgv = try Ruby.get("ARGV")

            let argv1 = ["a", "b", "c"]
            try Ruby.setArguments(argv1)
            XCTAssertEqual(argv1, Array<String>(rubyArgv))

            let argv2 = ["d"]
            try Ruby.setArguments(argv2)
            XCTAssertEqual(argv2, Array<String>(rubyArgv))
        }
    }
}
