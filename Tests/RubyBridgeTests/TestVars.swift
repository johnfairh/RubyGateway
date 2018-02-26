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
}
