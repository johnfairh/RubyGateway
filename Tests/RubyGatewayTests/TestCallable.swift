//
//  TestCallable.swift
//  RubyGatewayTests
//
//  Distributed under the MIT license, see LICENSE
//

import XCTest
import CRuby
@testable /* Qtrue */ import RubyGateway

/// Message send tests
class TestCallable: XCTestCase {

    // 'global' function
    func testCallGlobal() {
        doErrorFree {
            let res = try Ruby.call("sprintf", args: ["num=%d", 100])
            XCTAssertEqual("num=100", String(res))
        }
    }

    // Missing global
    func testCallGlobalFailure() {
        doError {
            let res = try Ruby.call("does_not_exist", args: [1, 2, 3])
            XCTFail("Managed to get \(res) back from invalid global call")
        }
    }

    // Get a new instance of MethodsTest
    private func getNewMethodTest() -> RbObject {
        return doErrorFree(fallback: .nilObject) {
            try Ruby.require(filename: Helpers.fixturePath("methods.rb"))
            return RbObject(ofClass: "MethodsTest")!
        }
    }

    // attribute
    func testAttribute() {
        let obj = getNewMethodTest()

        let attrName = "property"

        doErrorFree {
            let val = try obj.getAttribute(attrName)
            XCTAssertEqual("Default", String(val))

            let newVal = "Changed"

            try obj.setAttribute(attrName, newValue: newVal)
            let val2 = try obj.getAttribute(attrName)
            XCTAssertEqual(newVal, String(val2))
        }
    }

    // call
    func testVoidCall() {
        let obj = getNewMethodTest()

        doErrorFree {
            let val = try obj.call("noArgsMethod")
            XCTAssertTrue(val.isNil)
        }
    }

    // invalid call - bad message
    func testInvalidCall() {
        let obj = getNewMethodTest()

        doError {
            let val = try obj.call("does-not-exist")
            XCTFail("Managed to get \(val) out of invalid method")
        }

        doError {
            let val = try obj.call("")
            XCTFail("Managed to get \(val) out of invalid method")
        }
    }

    // multi-arg-type call
    func testMultiArgCall() {
        let obj = getNewMethodTest()

        doErrorFree {
            let val = try obj.call("threeArgsMethod", args: ["str", 8, 1.94e1])
            XCTAssertTrue(val.isTruthy)
        }
    }

    // missing args
    func testMissingArgCall() {
        let obj = getNewMethodTest()

        doError {
            let val = try obj.call("threeArgsMethod", args: ["str", 8])
            XCTFail("Managed to get \(val) with incomplete args")
        }
    }

    // 'get' chaining
    func testGetChaining() {
        let _ = getNewMethodTest()

        doErrorFree {
            let v = try Ruby.get("MethodsTest").get("classMethod")
            XCTAssertTrue(Bool(v)!)
        }
    }

    // kw args
    func testKwArgs() {
        let obj = getNewMethodTest()

        doErrorFree {
            let v = try obj.call("kwArgsMethod", args: [214], kwArgs: ["aSecond": 32])
            XCTAssertEqual(214 + 32 * 1, Int(v))
        }
    }

    // kw args, dup
    func testDupKwArgs() {
        let obj = getNewMethodTest()

        doErrorFree {
            do {
                let v = try obj.call("kwArgsMethod", args: [214], kwArgs: ["aSecond": 32, "aSecond": 38])
                XCTFail("Managed to pass duplicate keyword args to Ruby, got \(v)")
            } catch RbError.duplicateKwArg(let key) {
                XCTAssertEqual("aSecond", key)
            }
        }
    }

    // call via symbol
    func testCallViaSymbol() {
        let obj = getNewMethodTest()

        doErrorFree {
            let methodSym = try obj.getInstanceVar("@doubleMethod")
            XCTAssertEqual(.T_SYMBOL, methodSym.rubyType)

            let val = 38
            let result = try obj.call(symbol: methodSym, args: [38])
            XCTAssertEqual(val * 2, Int(result))
        }
    }

    // call via symbol - error case
    func testCallViaSymbolNotSymbol() {
        let obj = getNewMethodTest()

        doErrorFree {
            do {
                let res = try obj.call(symbol: RbObject("double"), args:[100])
                XCTFail("Managed to call something: \(res)")
            } catch RbError.badType(_) {
            }
        }
    }

    // call with a Swift block
    func testCallWithBlock() {
        let obj = getNewMethodTest()

        doErrorFree {
            let expectedRes = "answer"

            let res = try obj.call("yielder", kwArgs: ["value": 22]) { args in
                XCTAssertEqual(2, args.count)
                XCTAssertEqual(22, Int(args[0]))
                XCTAssertEqual("fish", String(args[1]))
                return RbObject(expectedRes)
            }
            XCTAssertEqual(expectedRes, String(res))

            // sym version
            let res2 = try obj.call(symbol: RbSymbol("yielder"), kwArgs: ["value": 22]) { args in
                XCTAssertEqual(2, args.count)
                XCTAssertEqual(22, Int(args[0]))
                XCTAssertEqual("fish", String(args[1]))
                return RbObject(expectedRes)
            }
            XCTAssertEqual(expectedRes, String(res2))
        }
    }

    // call with a Proc'd Swift block
    func testCallWithProcBlock() {
        let obj = getNewMethodTest()

        doErrorFree {
            let expectedRes = "answer"
            let proc = RbObject() { args in
                XCTAssertEqual(2, args.count)
                XCTAssertEqual(22, Int(args[0]))
                XCTAssertEqual("fish", String(args[1]))
                return RbObject(expectedRes)
            }
            let res = try obj.call("yielder2", block: proc)
            XCTAssertEqual(expectedRes, String(res))

            // sym version
            let res2 = try obj.call(symbol: RbSymbol("yielder2"), block: proc)
            XCTAssertEqual(expectedRes, String(res2))
        }
    }

    // yield kw args to a proc block
    func testCallWithProcBlockKwArgs() {
        let obj = getNewMethodTest()

        doErrorFree {
            let expectedRes = 22
            let proc = try Ruby.eval(ruby: "Proc.new { |a:| a }")
            let res = try obj.call("yielder3", args: [expectedRes], block: proc)
            XCTAssertEqual(expectedRes, Int(res))
        }
    }

    // Store a Swift block and later call it
    func testStoredSwiftBlock() {
        doErrorFree {
            let obj = getNewMethodTest()

            var counter = 0

            try obj.call("store_block", blockRetention: .self) { args in
                counter += 1
                return .nilObject
            }

            XCTAssertEqual(0, counter)

            try obj.call("call_block")
            XCTAssertEqual(1, counter)
        }
    }

    // Nil magic
    func testNilValue() {
        let obj = getNewMethodTest()

        doErrorFree {
            try obj.call("expectsNil", args: [nil])
        }
    }
}
