//
//  TestComplex.swift
//  RubyGateway
//
//  Distributed under the MIT license, see LICENSE
//

import XCTest
import RubyGateway

class TestComplex: XCTestCase {

    // Round trip the types
    func testRoundTrip() {
        let swiftNum = RbComplex(real: 1, imaginary: 1)
        let obj = RbObject(swiftNum)
        XCTAssertEqual("Complex", String(try obj.get("class")))

        guard let roundTripNum = RbComplex(obj) else {
            XCTFail("Couldn't convert complex number back to Swift")
            return
        }

        XCTAssertEqual(swiftNum.real, roundTripNum.real)
        XCTAssertEqual(swiftNum.imaginary, roundTripNum.imaginary)
    }

    // More sophisticated conversion
    func testConversion() {
        let real = 1.2
        let imaginary = 4
        let complexStr = "\(real)+\(imaginary)i"

        guard let num = RbComplex(complexStr) else {
            XCTFail("Couldn't create complex number")
            return
        }

        XCTAssertEqual(real, num.real)
        XCTAssertEqual(Double(imaginary), num.imaginary)
    }

    // Error case
    func testUnconvertible() {
        let someProc = RbObject() { args in .nilObject }
        if let num = RbComplex(someProc) {
            XCTFail("Managed to convert proc to complex: \(num)")
            return
        }
    }
}
