//
//  TestComplex.swift
//  RubyGateway
//
//  Distributed under the MIT license, see LICENSE
//

import XCTest
import RubyGateway

class TestComplex: XCTestCase {

    func testRoundTrip() {
        doErrorFree {
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
    }

    static var allTests = [
        ("testRoundTrip", testRoundTrip),
    ]
}
