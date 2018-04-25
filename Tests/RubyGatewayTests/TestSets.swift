//
//  TestSets.swift
//  RubyGatewayTests
//
//  Distributed under the MIT license, see LICENSE
//

import XCTest
import RubyGateway

class TestSets: XCTestCase {

    func testRoundTrip() {
        let aSet: Set<Int> = [1, 2, 3, 4]
        let rbSet = RbObject(aSet)
        guard let backSet = Set<Int>(rbSet) else {
            XCTFail("Couldn't convert set back - \(rbSet)")
            return
        }
        XCTAssertEqual(aSet, backSet)
    }

    static var allTests = [
        ("testRoundTrip", testRoundTrip),
    ]
}
