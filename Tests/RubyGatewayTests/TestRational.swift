//
//  TestRational.swift
//  RubyGateway
//
//  Distributed under the MIT license, see LICENSE
//

import XCTest
import RubyGateway

class TestRational: XCTestCase {

    // Round trip the types
    func testRoundTrip() {
        let swiftNum = RbRational(numerator: Double.pi, denominator: 2)
        let obj = RbObject(swiftNum)
        XCTAssertEqual("Rational", String(try obj.get("class")))

        guard let roundTripNum = RbRational(obj) else {
            XCTFail("Couldn't convert rational number back to Swift")
            return
        }

        // this test is slightly fishy...
        XCTAssertEqual(swiftNum.numerator / swiftNum.denominator,
                       roundTripNum.numerator / roundTripNum.denominator)
    }

    // More sophisticated conversion
    func testConversion() {
        let num = -2
        let denom = 3
        let ratStr = "\(num)/\(denom)"

        guard let rat = RbRational(ratStr) else {
            XCTFail("Couldn't create rational number")
            return
        }

        XCTAssertEqual(Double(num), rat.numerator)
        XCTAssertEqual(Double(denom), rat.denominator)
    }

    // Error case
    func testUnconvertible() {
        let someProc = RbObject() { args in .nilObject }
        if let num = RbRational(someProc) {
            XCTFail("Managed to convert proc to rational: \(num)")
            return
        }
    }

    // Swift normalization helper
    func testSwiftInput() {
        let numerator = Double.pi, denominator = 4.0

        let rat1 = RbRational(numerator: numerator, denominator: -denominator)
        let rat2 = RbRational(numerator: -numerator, denominator: denominator)

        XCTAssertEqual(rat1.numerator, rat2.numerator)
        XCTAssertEqual(rat1.denominator, rat2.denominator)

        let ratObj1 = rat1.rubyObject, ratObj2 = rat2.rubyObject
        XCTAssertFalse(ratObj1.isNil)

        XCTAssertEqual(ratObj1, ratObj2)
    }
}
