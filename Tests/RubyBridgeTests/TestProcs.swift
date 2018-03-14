//
//  TestProcs.swift
//  RubyBridgeTests
//
//  Distributed under the MIT license, see LICENSE
//

import XCTest
import RubyBridge

/// Proc tests
class TestProcs: XCTestCase {

    /// Create and call simple swift proc
    func testCall() {
        do {
            let expectedArg0 = "argString"
            let expectedArg1 = 102.8
            let expectedArgCount = 2
            let expectedResult = -7002

            let proc = RbProc() { args in
                XCTAssertEqual(expectedArgCount, args.count)
                XCTAssertEqual(expectedArg0, String(args[0]))
                XCTAssertEqual(expectedArg1, Double(args[1]))
                return RbObject(expectedResult)
            }

            let result = try proc.rubyObject.call("call", args: [expectedArg0, expectedArg1])

            XCTAssertEqual(expectedResult, Int(result))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    static var allTests = [
        ("testCall", testCall)
    ]
}
