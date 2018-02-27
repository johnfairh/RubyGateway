//
//  TestCallable.swift
//  RubyBridgeTests
//
//  Distributed under the MIT license, see LICENSE
//

import XCTest
import CRuby
@testable import RubyBridge

/// Message send tests
class TestRbCallable: XCTestCase {

    // array, hash
    // kw-param - works, excess, missing, optional

    // 'global' function
    func testCallGlobal() {
        do {
            let res = try Ruby.call("sprintf", args: ["num=%d", 100])
            XCTAssertEqual("num=100", String(res))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // Missing global
    func testCallGlobalFailure() {
        do {
            let res = try Ruby.call("does_not_exist", args: [1, 2, 3])
            XCTFail("Managed to get \(res) back from invalid global call")
        } catch {
        }
    }

    // Get a new instance of MethodsTest
    private func getNewMethodTest() -> RbObject {
        do {
            try Ruby.require(filename: Helpers.fixturePath("methods.rb"))
            return try Ruby.getClass("MethodsTest").call("new")
        } catch {
            XCTFail("Unexpected exception: \(error)")
            return RbObject(rubyValue: Qundef)
        }
    }

    // attribute
    func testAttribute() {
        let obj = getNewMethodTest()

        let attrName = "property"

        do {
            let val = try obj.getAttribute(attrName)
            XCTAssertEqual("Default", String(val))

            let newVal = "Changed"

            try obj.setAttribute(attrName, newValue: newVal)
            let val2 = try obj.getAttribute(attrName)
            XCTAssertEqual(newVal, String(val2))
        } catch {
            XCTFail("Unexpected exception: \(error)")
        }
    }

    // call
    func testVoidCall() {
        let obj = getNewMethodTest()

        do {
            let val = try obj.call("noArgsMethod")
            XCTAssertTrue(val.isNil)
        } catch {
            XCTFail("Unexpected exception: \(error)")
        }
    }

    // invalid call - bad message
    func testInvalidCall() {
        let obj = getNewMethodTest()

        do {
            let val = try obj.call("does-not-exist")
            XCTFail("Managed to get \(val) out of invalid method")
        } catch {
        }
    }

    // multi-arg-type call
    func testMultiArgCall() {
        let obj = getNewMethodTest()

        do {
            let val = try obj.call("threeArgsMethod", args: ["str", 8, 1.94e1])
            XCTAssertTrue(val.isTruthy)
        } catch {
            XCTFail("Unexpected exception: \(error)")
        }
    }

    // missing args
    func testMissingArgCall() {
        let obj = getNewMethodTest()

        do {
            let val = try obj.call("threeArgsMethod", args: ["str", 8])
            XCTFail("Managed to get \(val) with incomplete args")
        } catch {
        }
    }

    // 'get' chaining
    func testGetChaining() {
        let _ = getNewMethodTest()

        do {
            let v = try Ruby.get("MethodsTest").get("classMethod")
            XCTAssertEqual(Qtrue, v.rubyValue)
        } catch {
            XCTFail("Unexpected exception \(error)")
        }
    }

    // kw args
    func testKwArgs() {
        let obj = getNewMethodTest()

        do {
            let v = try obj.call("kwArgsMethod", args: [214], kwArgs: [("aSecond", 32)])
            XCTAssertEqual(214 + 32 * 1, Int(v))
        } catch {
            XCTFail("Unexpected exception \(error)")
        }
    }

    // kw args, dup
    func testDupKwArgs() {
        let obj = getNewMethodTest()

        do {
            let v = try obj.call("kwArgsMethod", args: [214], kwArgs: [("aSecond", 32), ("aSecond", 38)])
            XCTFail("Managed to pass duplicate keyword args to Ruby, got \(v)")
        } catch RbError.duplicateKwArg(let key) {
            XCTAssertEqual("aSecond", key)
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }
}
