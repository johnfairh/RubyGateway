//
//  TestStrings.swift
//  TMLRubyTests
//
//  Created by John Fairhurst on 16/02/2018.
//

import XCTest
@testable import RubyBridge
import CRuby

/// Tests for String helpers
///
/// TODO - protect + failable inzn

class TestStrings: XCTestCase {

    override func setUp() {
        let _ = Helpers.ruby
    }

    private func doTestRoundTrip(_ string: String) {
        // Swift to Ruby
        let rubyVal = string.withCString { rb_utf8_str_new($0, string.utf8.count) }
        XCTAssertTrue(RB_TYPE_P(rubyVal, .T_STRING))

        // Ruby to Swift - dance through Data to handle embedded nuls
        let rubyLength = RSTRING_LEN(rubyVal)
        let rubyPtr = RSTRING_PTR(rubyVal)
        let rubyData = Data(bytes: rubyPtr, count: rubyLength)

        guard let backString = String(data: rubyData, encoding: .utf8) else {
            XCTFail("Oops, UTF8 not preserved??")
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

    static var allTests = [
        ("testEmpty", testEmpty),
        ("testAscii", testAscii),
        ("testUtf8", testUtf8),
        ("testUtf8WithNulls", testUtf8WithNulls)
    ]
}
