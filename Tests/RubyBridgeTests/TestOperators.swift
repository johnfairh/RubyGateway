//
//  TestOperators.swift
//  RubyBridgeTests
//
//  Distributed under the MIT license, see LICENSE
//

import XCTest
import RubyBridge

/// Some not-very-comprehensive tests for numeric support - at least check the Swift
/// operators are hooked up to the right Ruby ones.
class TestOperators: XCTestCase {

    func testBasicIntegers() {
        let aVal = 12
        let bVal = -6

        let aValObj = RbObject(exactly: aVal)
        let bValObj = RbObject(exactly: bVal)

        XCTAssertEqual(Int(aVal + bVal), Int(aValObj + bValObj))

        XCTAssertEqual(Int(aVal - bVal), Int(aValObj - bValObj))

        XCTAssertEqual(Int(aVal * bVal), Int(aValObj * bValObj))

        XCTAssertEqual(Int(aVal / bVal), Int(aValObj / bValObj))

        XCTAssertEqual(Int(aVal % bVal), Int(aValObj % bValObj))

        XCTAssertEqual(-aVal, Int(-aValObj))
        XCTAssertEqual(-bVal, Int(-bValObj))

        XCTAssertEqual(+aVal, Int(+aValObj))
        XCTAssertEqual(+bVal, Int(+bValObj))

        XCTAssertEqual(aVal.magnitude, UInt(aValObj.magnitude))
        XCTAssertEqual(bVal.magnitude, UInt(bValObj.magnitude))
    }

    func testMutating() {
        var aVal = 3.4
        let bVal = 5.8

        var aValObj = RbObject(aVal)
        let bValObj = RbObject(bVal)

        XCTAssertEqual(aVal, Double(aValObj))
        XCTAssertEqual(bVal, Double(bValObj))

        aVal += bVal
        aValObj += bValObj
        XCTAssertEqual(aVal, Double(aValObj))

        aVal *= bVal
        aValObj *= bValObj
        XCTAssertEqual(aVal, Double(aValObj))

        aVal -= bVal
        aValObj -= bValObj
        XCTAssertEqual(aVal, Double(aValObj))

        aVal /= bVal
        aValObj /= bValObj
        XCTAssertEqual(aVal, Double(aValObj))

        aVal.formTruncatingRemainder(dividingBy: bVal)
        aValObj %= bValObj
        XCTAssertEqual(aVal, Double(aValObj))
    }

    static var allTests = [
        ("testBasicIntegers", testBasicIntegers),
        ("testMutating", testMutating)
    ]
}
