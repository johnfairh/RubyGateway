//
//  TestOperators.swift
//  RubyGatewayTests
//
//  Distributed under the MIT license, see LICENSE
//

import XCTest
import RubyGateway

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

    func testSubscript() {
        doErrorFree {
            try Ruby.require(filename: Helpers.fixturePath("methods.rb"))
            guard let inst = RbObject(ofClass: "MethodsTest") else {
                XCTFail("Couldn't create instance")
                return
            }

            let val1 = 1
            let val2 = 4.5
            let str = inst[val1, val2]
            XCTAssertEqual("\(val1) \(val2)", String(str))

            let val3 = "fred"
            inst[val1, val2] = RbObject(val3)
            XCTAssertEqual("\(val1) \(val2) = \(val3)", String(try inst.getInstanceVar("@subscript_set")))
        }
    }
}
