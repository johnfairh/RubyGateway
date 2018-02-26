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
}
