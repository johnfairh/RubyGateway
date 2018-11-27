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

            let funcName = "myGlobal1"
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

            let actualRetValue = try Ruby.eval(ruby: "\(funcName)(\"\(argValue)\")")

            XCTAssertTrue(visited)
            XCTAssertEqual(retValue, Double(actualRetValue))
        }
    }

    // Argc runtime mismatch
    func testArgcMismatch() {
        doErrorFree {
            let funcName = "myGlobal2"
            let expectedArgCount = 1

            try Ruby.defineGlobalFunction(name: funcName, argc: expectedArgCount) { _, _ in
                XCTFail("Accidentally called function requiring an arg without any")
                return .nilObject
            }

            doError {
                let _ = try Ruby.eval(ruby: "\(funcName)()")
            }
        }
    }

    // invalid argc request
    func testInvalidArgsCount() {
        doError {
            try Ruby.defineGlobalFunction(name: "bad_boy", argc: 103) { _, _ in return .nilObject }
        }
    }

    static var allTests = [
        ("testFixedArgsRoundTrip", testFixedArgsRoundTrip),
        ("testInvalidArgsCount", testInvalidArgsCount)
    ]
}
