//
//  TestStrings.swift
//  RubyBridgeTests
//
//  Distributed under the MIT license, see LICENSE
//

import XCTest
@testable import RubyBridge
import CRuby

/// Tests for String helpers
///
/// TODO - protect + failable inzn

class TestStrings: XCTestCase {

    private func doTestRoundTrip(_ string: String) {
        let rubyObj = RbObject(string)
        XCTAssertTrue(RB_TYPE_P(rubyObj.rubyValue, .T_STRING))

        guard let backString = String(rubyObj) else {
            XCTFail("Oops, to_s failed??")
            return
        }
        XCTAssertEqual(string, backString)
    }

    func testEmpty() {
        doTestRoundTrip("")
    }

    func testAscii() {
        doTestRoundTrip("A test string")
    }

    func testUtf8() {
        doTestRoundTrip("abë🐽🇧🇷end")
    }

    func testUtf8WithNulls() {
        doTestRoundTrip("abë\0🐽🇧🇷en\0d")
    }

    func testFailedStringConversion() {
        try! Ruby.require(filename: Helpers.fixturePath("nonconvert.rb"))

        let instance: VALUE
        do {
            instance = try Ruby.eval(ruby: "Nonconvert.new")
            XCTAssertEqual(.T_OBJECT, TYPE(instance))
        } catch {
            XCTFail("Unexpected error: \(error)")
            return
        }
        let obj = RbObject(rubyValue: instance)
        if let str = String(obj) {
            XCTFail("Converted unconvertible: \(str)")
        }
    }

    func testLiteralPromotion() {
        let obj: RbObject = "test string"
        XCTAssertEqual("test string", String(obj))
    }

    static var allTests = [
        ("testEmpty", testEmpty),
        ("testAscii", testAscii),
        ("testUtf8", testUtf8),
        ("testUtf8WithNulls", testUtf8WithNulls),
        ("testFailedStringConversion", testFailedStringConversion),
        ("testLiteralPromotion", testLiteralPromotion)
    ]
}
