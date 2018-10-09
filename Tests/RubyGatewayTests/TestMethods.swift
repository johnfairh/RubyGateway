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

    // basic round-trip
    func testFixedArgsRoundTrip() {
        doErrorFree {

            let funcName = "myGlobal"
            var visited = false

            try Ruby.defineGlobalFunction(name: funcName, args: 0) { obj, method in
                XCTAssertFalse(visited)
                visited = true
                return .nilObject
            }

            XCTAssertTrue(visited)
        }
    }

    static var allTests = [
        ("testFixedArgsRoundTrip", testFixedArgsRoundTrip)
    ]
}
