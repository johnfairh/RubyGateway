//
//  TestMethods.swift
//  RubyGatewayTests
//
//  Distributed under the MIT license, see LICENSE
//

import Foundation
import XCTest
import RubyGateway

/// Swift methods
class TestMethods: XCTestCase {

    // basic data round-trip
    func testFixedArgsRoundTrip() {
        doErrorFree {
            let funcName = "myGlobal"
            let argCount = 1
            let argValue = "Fish"
            let retValue = 8.9
            var visited = false

            try Ruby.defineGlobalFunction(name: funcName, argc: argCount) { _, method in
                XCTAssertFalse(visited)
                visited = true
                XCTAssertEqual(argCount, method.argv.count)
                XCTAssertEqual(argValue, String(method.argv[0]))
                return RbObject(retValue)
            }

            let actualRetValue = try Ruby.call(funcName, args: [argValue])

            XCTAssertTrue(visited)
            XCTAssertEqual(retValue, Double(actualRetValue))
        }
    }

    func testVarArgsRoundTrip() {
        doErrorFree {
            let funcName = "myGlobal"
            let retValue = 8.9
            var visited = false

            try Ruby.defineGlobalFunction(name: funcName) { _, method in
                XCTAssertFalse(visited)
                visited = true
                XCTAssertEqual(method.argv.count, 0)
                return RbObject(retValue)
            }

            let actualRetValue = try Ruby.call(funcName)

            XCTAssertTrue(visited)
            XCTAssertEqual(retValue, Double(actualRetValue))
        }
    }

    // Argc runtime mismatch
    func testArgcMismatch() {
        doErrorFree {
            let funcName = "myGlobal"
            let expectedArgCount = 1

            try Ruby.defineGlobalFunction(name: funcName, argc: expectedArgCount) { _, _ in
                XCTFail("Accidentally called function requiring an arg without any")
                return .nilObject
            }

            doError {
                let _ = try Ruby.call(funcName)
            }
        }
    }

    // invalid argc request
    func testInvalidArgsCount() {
        doError {
            try Ruby.defineGlobalFunction(name: "bad_boy", argc: 103) { _, _ in return .nilObject }
        }
    }

    // Goodpath calling Swift + Ruby block from a function
    func testGoodBlock() {
        doErrorFree {
            let funcName = "myGlobal"
            var funcCalled = false
            var blockCalled = false
            let expectedBlockResult = 4.0
            let expectedFuncResult = "alldone"

            try Ruby.defineGlobalFunction(name: funcName) { _, method in
                XCTAssertTrue(method.isBlockGiven)
                XCTAssertFalse(funcCalled)
                let blockResult = try method.yieldBlock()
                XCTAssertEqual(expectedBlockResult, Double(blockResult))
                funcCalled = true
                return RbObject(expectedFuncResult)
            }

            let funcResult = try Ruby.call(funcName) { blockArgs in
                XCTAssertFalse(blockCalled)
                blockCalled = true
                XCTAssertEqual(0, blockArgs.count)
                return RbObject(expectedBlockResult)
            }

            XCTAssertTrue(funcCalled)
            XCTAssertTrue(blockCalled)
            XCTAssertEqual(expectedFuncResult, String(funcResult))

            // Do the ruby version too!
            funcCalled = false
            let _ = try Ruby.eval(ruby: "\(funcName) { next 4.0 }")
            XCTAssertTrue(funcCalled)
        }
    }

    // Missing block
    func testErrorNoBlock() {
        doErrorFree {
            let funcName = "myGlobal"
            var funcCalled = false

            try Ruby.defineGlobalFunction(name: funcName) { _, method in
                funcCalled = true
                try method.needsBlock()
                return .nilObject
            }

            doError {
                let _ = try Ruby.call(funcName)
            }
            XCTAssertTrue(funcCalled)
        }
    }

    // Manual block invocation
    func testManualBlock() {
        doErrorFree {
            let funcName = "myGlobal"
            var funcCalled = false
            var blockCalled = false

            try Ruby.defineGlobalFunction(name: funcName) { _, method in
                let block = try method.captureBlock()
                try block.call("call")
                funcCalled = true
                return .nilObject
            }

            try Ruby.call(funcName) { blockArgs in
                blockCalled = true
                XCTAssertEqual(0, blockArgs.count)
                return .nilObject
            }

            XCTAssertTrue(funcCalled)
            XCTAssertTrue(blockCalled)
        }
    }

    // Block with args
    func testBlockArgs() {
        doErrorFree {
            let funcName = "myGlobal"
            var funcCalled = false
            var blockCalled = false
            let expectedBlockArg = 4.0

            try Ruby.defineGlobalFunction(name: funcName) { _, method in
                XCTAssertTrue(method.isBlockGiven)
                try method.needsBlock()
                XCTAssertFalse(funcCalled)
                let _ = try method.yieldBlock(args: [expectedBlockArg])
                funcCalled = true
                return .nilObject
            }

            let _ = try Ruby.call(funcName) { blockArgs in
                XCTAssertFalse(blockCalled)
                blockCalled = true
                XCTAssertEqual(1, blockArgs.count)
                XCTAssertEqual(expectedBlockArg, Double(blockArgs[0]))
                return .nilObject
            }

            XCTAssertTrue(funcCalled)
            XCTAssertTrue(blockCalled)
        }
    }

    // break / return / next from block
    func testBlockBreakReturn() {
        doErrorFree {
            try Ruby.require(filename: Helpers.fixturePath("swift_methods.rb"))

            try Ruby.defineGlobalFunction(name: "swift_calls_block") { _, method in
                try method.needsBlock()
                let _ = try method.yieldBlock()
                return RbObject(100)
            }

            try Ruby.defineGlobalFunction(name: "swift_returns_block") { _, method in
                try method.needsBlock()
                return try method.yieldBlock()
            }

            let testSuffixes = [100, 42, 200, 44, 22, 24, 4]
            try testSuffixes.forEach { val in
                let funcName = "ruby_should_return_\(val)"
                let result = try Ruby.call(funcName)
                XCTAssertEqual(val, Int(result))
            }
        }
    }

    static var allTests = [
        ("testFixedArgsRoundTrip", testFixedArgsRoundTrip),
        ("testVarArgsRoundTrip", testVarArgsRoundTrip),
        ("testArgcMismatch", testArgcMismatch),
        ("testInvalidArgsCount", testInvalidArgsCount),
        ("testGoodBlock", testGoodBlock),
        ("testErrorNoBlock", testErrorNoBlock),
        ("testManualBlock", testManualBlock),
        ("testBlockArgs", testBlockArgs),
        ("testBlockBreakReturn", testBlockBreakReturn)
    ]
}
