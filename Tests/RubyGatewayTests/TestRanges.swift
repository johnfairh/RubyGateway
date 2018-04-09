//
//  TestRange.swift
//  RubyGatewayTests
//
//  Distributed under the MIT license, see LICENSE
//

import XCTest
import RubyGateway

class TestRange: XCTestCase {

    // basic round-tripping

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

    // closed/half-open error cases

    private func closedRubyRange() -> RbObject {
        return RbObject(ofClass: "Range", args: [5, 103, false])!
    }

    private func halfOpenRubyRange() -> RbObject {
        return RbObject(ofClass: "Range", args: [5, 103, true])!
    }

    func testRangeTypes() {
        if let r = Range<Int>(closedRubyRange()) {
            XCTFail("Made Range out of closed range: \(r)")
            return
        }

        if let r = CountableRange<Int>(closedRubyRange()) {
            XCTFail("Made CountableRange out of closed range: \(r)")
            return
        }

        if let cr = ClosedRange<Int>(halfOpenRubyRange()) {
            XCTFail("Made ClosedRange out of half-open range: \(cr)")
            return
        }

        if let cr = CountableClosedRange<Int>(halfOpenRubyRange()) {
            XCTFail("Made ClosedRange out of half-open range: \(cr)")
            return
        }
    }

    // unconvertable Range

    func testBadRange() {
        do {
            try Ruby.require(filename: Helpers.fixturePath("nonconvert.rb"))

            guard let rangeObj = RbObject(ofClass: "BadRange") else {
                XCTFail("Couldn't create bad range")
                return
            }

            if let r = Range<Int>(rangeObj) {
                XCTFail("Managed to create backwards range: \(r)")
                return
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    static var allTests = [
        ("testRoundTrip", testRoundTrip),
        ("testRoundTripClosed", testRoundTripClosed),
        ("testRoundTripCountable", testRoundTripCountable),
        ("testRoundTripCountableClosed", testRoundTripCountableClosed),
        ("testRangeTypes", testRangeTypes)
    ]
}
