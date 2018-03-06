//
//  TestOperators.swift
//  RubyBridgeTests
//
//  Distributed under the MIT license, see LICENSE
//

import XCTest
import RubyBridge

/// Some not-very-comprehensive tests for numeric support.
class TestOperators: XCTestCase {

    func testBasicIntegers() {
        let aVal = 12
        let bVal = -6

        let aValObj = RbObject(aVal)
        let bValObj = RbObject(bVal)

        XCTAssertEqual(Int(aVal + bVal), Int(aValObj + bValObj))
    }

}
