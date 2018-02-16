//
//  TestStrings.swift
//  TMLRubyTests
//
//  Created by John Fairhurst on 16/02/2018.
//

import XCTest
import TMLRuby
import CRuby

/// Tests for String helpers
///
/// TODO - explore utf8ness (emoji)
///      - protect
///      - embedded nulls!
class TestStrings: XCTestCase {

    override func setUp() {
        let _ = Helpers.ruby
    }

    // Round-trip in the normal way
    func testRoundTrip_C() {
        let testString = "A test string"
        let rubyVal = testString.withCString { rb_str_new_cstr($0) }
        let backString = String(cString: StringValueCStr(rubyVal))
        XCTAssertEqual(testString, backString)

        let rubyVal2 = StringValue(rubyVal)
        let backString2 = String(cString: StringValueCStr(rubyVal2))
        XCTAssertEqual(testString, backString2)
    }

    // Round-trip the hard way, allowing for nuls
    func testRoundTrip_Len() {
        let testString = "A test string"
        let rubyVal = testString.withCString { rb_str_new_cstr($0) }

        let rubyLength = RSTRING_LEN(rubyVal)
        XCTAssertEqual(testString.utf8.count, rubyLength)

        let rubyChars = StringValuePtr(rubyVal)!

        var backString = String()
        for x in 0..<rubyLength {
            backString.append(Character(UnicodeScalar(rubyChars[x])))
        }

        XCTAssertEqual(testString, backString)
    }
}
