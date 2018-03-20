//
//  TestCallable.swift
//  RubyGatewayTests
//
//  Distributed under the MIT license, see LICENSE
//

import XCTest
import CRuby
@testable /* Qtrue */ import RubyBridge

/// Message send tests
class TestCallable: XCTestCase {

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
            return RbObject(ofClass: "MethodsTest")!
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

        do {
            let val = try obj.call("")
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
            XCTAssertTrue(Bool(v)!)
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

    // call via symbol
    func testCallViaSymbol() {
        let obj = getNewMethodTest()

        do {
            let methodSym = try obj.getInstanceVar("@doubleMethod")
            XCTAssertEqual(.T_SYMBOL, methodSym.rubyType)

            let val = 38
            let result = try obj.call(symbol: methodSym, args: [38])
            XCTAssertEqual(val * 2, Int(result))
        } catch {
            XCTFail("Unexpected exception \(error)")
        }
    }

    // call via symbol - error case
    func testCallViaSymbolNotSymbol() {
        let obj = getNewMethodTest()

        do {
            let res = try obj.call(symbol: RbObject("double"), args:[100])
            XCTFail("Managed to call something: \(res)")
        } catch RbError.badType(_) {
        } catch {
            XCTFail("Unexpected exception: \(error)")
        }
    }

    // call with a Swift block
    func testCallWithBlock() {
        let obj = getNewMethodTest()

        do {
            let expectedRes = "answer"

            let res = try obj.call("yielder") { args in
                XCTAssertEqual(2, args.count)
                XCTAssertEqual(22, Int(args[0]))
                XCTAssertEqual("fish", String(args[1]))
                return RbObject(expectedRes)
            }
            XCTAssertEqual(expectedRes, String(res))

            // sym version
            let res2 = try obj.call(symbol: RbSymbol("yielder")) { args in
                XCTAssertEqual(2, args.count)
                XCTAssertEqual(22, Int(args[0]))
                XCTAssertEqual("fish", String(args[1]))
                return RbObject(expectedRes)
            }
            XCTAssertEqual(expectedRes, String(res2))

        } catch {
            XCTFail("Unexpected exception: \(error)")
        }
    }

    // call with a Proc'd Swift block
    func testCallWithProcBlock() {
        let obj = getNewMethodTest()

        do {
            let expectedRes = "answer"
            let proc = RbObject() { args in
                XCTAssertEqual(2, args.count)
                XCTAssertEqual(22, Int(args[0]))
                XCTAssertEqual("fish", String(args[1]))
                return RbObject(expectedRes)
            }
            let res = try obj.call("yielder", block: proc)
            XCTAssertEqual(expectedRes, String(res))

            // sym version
            let res2 = try obj.call(symbol: RbSymbol("yielder"), block: proc)
            XCTAssertEqual(expectedRes, String(res2))
        } catch {
            XCTFail("Unexpected exception: \(error)")
        }
    }

    // Store a Swift block and later call it
    func testStoredSwiftBlock() {
        do {
            let obj = getNewMethodTest()

            var counter = 0

            try obj.call("store_block", blockRetention: .self) { args in
                counter += 1
                return .nilObject
            }

            XCTAssertEqual(0, counter)

            try obj.call("call_block")
            XCTAssertEqual(1, counter)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    static var allTests = [
        ("testCallGlobal", testCallGlobal),
        ("testCallGlobalFailure", testCallGlobalFailure),
        ("testAttribute", testAttribute),
        ("testVoidCall", testVoidCall),
        ("testInvalidCall", testInvalidCall),
        ("testMultiArgCall", testMultiArgCall),
        ("testMissingArgCall", testMissingArgCall),
        ("testGetChaining", testGetChaining),
        ("testKwArgs", testKwArgs),
        ("testDupKwArgs", testDupKwArgs),
        ("testCallViaSymbol", testCallViaSymbol),
        ("testCallViaSymbolNotSymbol", testCallViaSymbolNotSymbol),
        ("testCallWithBlock", testCallWithBlock),
        ("testCallWithProcBlock", testCallWithProcBlock),
        ("testStoredSwiftBlock", testStoredSwiftBlock)
    ]
}
