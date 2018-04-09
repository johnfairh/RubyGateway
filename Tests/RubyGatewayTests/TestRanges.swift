//
//  TestRange.swift
//  RubyGatewayTests
//
//  Distributed under the MIT license, see LICENSE
//

import XCTest
import RubyGateway

class TestRange: XCTestCase {

    func testRoundTrip() {
        let range = Range(13..<29)
        let rbRange = range.rubyObject
        XCTAssertEqual(range, Range<Int>(rbRange))
    }

    func testRoundTripClosed() {
        let range = ClosedRange(13...29)
        let rbRange = range.rubyObject
        XCTAssertEqual(range, ClosedRange<Int>(rbRange))
    }

    func testRoundTripCountable() {
        let range = 13..<29
        let rbRange = range.rubyObject
        XCTAssertEqual(range, CountableRange<Int>(rbRange))
    }

    func testRoundTripCountableClosed() {
        let range = 13...29
        let rbRange = range.rubyObject
        XCTAssertEqual(range, CountableClosedRange<Int>(rbRange))
    }

    static var allTests = [
        ("testRoundTrip", testRoundTrip),
        ("testRoundTripClosed", testRoundTripClosed),
        ("testRoundTripCountable", testRoundTripCountable),
        ("testRoundTripCountableClosed", testRoundTripCountableClosed)
    ]
}
