//
//  TestVars.swift
//  RubyBridgeTests
//
//  Distributed under the MIT license, see LICENSE
//

import XCTest
import RubyBridge
import Foundation

/// Test global etc. vars work
class TestVars: XCTestCase {

    // built-in
    func testBuiltinGlobalVar() {
        do {
            guard let rubyPid = try Int32(Ruby.getGlobalVar("$$")) else {
                XCTFail("Non-numeric value for $$")
                return
            }
            XCTAssertEqual(getpid(), rubyPid)
        } catch {
            XCTFail("Unexpected exception \(error)")
        }
    }

    // new var
    func testNewGlobalVar() {
        do {
            let varName = "$MY_GLOBAL"
            let obj = try Ruby.getGlobalVar(varName)
            XCTAssertTrue(obj.isNil)

            let testValue = 4.1

            try Ruby.setGlobalVar(varName, newValue: testValue)

            // various ways of reading it
            func check(_ obj: RbObject) throws {
                guard let dblVal = Double(obj) else {
                    XCTFail("Not floating point: \(obj)")
                    return
                }
                XCTAssertEqual(testValue, dblVal)
            }

            try check(Ruby.getGlobalVar(varName))
            try check(Ruby.get(varName))
            try check(Ruby.eval(ruby: varName))
        } catch {
            XCTFail("Unexpected exception \(error)")
        }
    }

    // name check...
    func testGlobalVarNameCheck() {
        do {
            try Ruby.setGlobalVar("LOVELY_GVAR", newValue: 22)
            XCTFail("Managed to set global without $name")
        } catch {
        }
    }

    // instance vars - top self - create/get/set/check
    func testTopInstanceVar() {
        do {
            let varName = "@new_main_ivar"
            let obj = try Ruby.getInstanceVar(varName)
            XCTAssertTrue(obj.isNil)

            let testValue = 1002

            try Ruby.setInstanceVar(varName, newValue: testValue)

            // various ways of reading it

            try XCTAssertEqual(testValue, Int(Ruby.getInstanceVar(varName)))
            try XCTAssertEqual(testValue, Int(Ruby.get(varName)))
            try XCTAssertEqual(testValue, Int(Ruby.eval(ruby: varName)))
        } catch {
            XCTFail("Unexpected exception \(error)")
        }
    }

    // instance vars - regular objects
    func testInstanceVar() {
        do {
            try Ruby.require(filename: Helpers.fixturePath("methods.rb"))

            let obj = try Ruby.get("MethodsTest").call("new")

            let ivarName = "@property"
            let ivarObj = try obj.getInstanceVar(ivarName)
            XCTAssertEqual("Default", String(ivarObj))

            let newValue = "Changed"

            try obj.setInstanceVar(ivarName, newValue: newValue)

            try XCTAssertEqual(newValue, String(obj.getInstanceVar(ivarName)))
            try XCTAssertEqual(newValue, String(obj.get(ivarName)))
        } catch {
            XCTFail("Unexpected exception \(error)")
        }
    }

    // name check...
    func testIVarNameCheck() {
        do {
            try Ruby.setInstanceVar("LOVELY_IVAR", newValue: 22)
            XCTFail("Managed to set ivar without @name")
        } catch {
        }

        do {
            try Ruby.setInstanceVar("@@LOVELY_IVAR", newValue: 22)
            XCTFail("Managed to set ivar with @@name")
        } catch {
        }
    }

    // class vars special rule
    func testAbsentClassVar() {
        do {
            let varName = "@@new_main_cvar"
            let obj = try Ruby.getClassVar(varName)
            XCTFail("Managed to read non-existent cvar: \(obj)")
        } catch {
        }
    }

    // cvar round-trip
    func testWriteClassVar() {
        do {
            let varName = "@@new_cvar"
            let value = 103.8

            // top level is cObject so all works...

            try Ruby.setClassVar(varName, newValue: RbObject(value))

            try XCTAssertEqual(value, Double(Ruby.getClassVar(varName)))
            try XCTAssertEqual(value, Double(Ruby.get(varName)))
            try XCTAssertEqual(value, Double(Ruby.eval(ruby: varName)))
        } catch {
            XCTFail("Unexpected exception \(error)")
        }
    }

    // cvar on not-class
    func testNotClassClassVar() {
        do {
            let obj = RbObject("AString")

            try obj.setClassVar("@@new_cvar", newValue: 105)
            XCTFail("Managed to set class var on non-class")
        } catch RbError.badType(_) {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        do {
            let obj = RbObject("AString")

            let cvar = try obj.getClassVar("@@new_cvar")
            XCTFail("Managed to get class var on non-class: \(cvar)")
        } catch RbError.badType(_) {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // cvar name check
    func testCVarNameCheck() {
        do {
            try Ruby.setClassVar("LOVELY_CVAR", newValue: 22)
            XCTFail("Managed to set cvar without @@name")
        } catch {
        }

        do {
            try Ruby.setClassVar("@LOVELY_CVAR", newValue: 22)
            XCTFail("Managed to set cvar with @name")
        } catch {
        }
    }
}
