//
//  TestNumerics.swift
//  TMLRubyTests
//
//  Created by John Fairhurst on 16/02/2018.
//

import XCTest
import TMLRuby

/// A bunch of the Ruby numeric conversion macros don't make it through
/// the importer so are re-implemented in various ways.  These tests check
/// they're OK.
class TestNumerics: XCTestCase {

    /// Check we can round-trip values through fixnum, that our
    /// understanding matches Ruby's.
    func testFixnumRoundtrip() {
        let values = [RUBY_FIXNUM_MIN, 0, RUBY_FIXNUM_MAX]
        values.forEach { val in
            XCTAssertTrue(RB_FIXABLE(val))
            let rubyVal = RB_LONG2FIX(val)
            XCTAssertTrue(RB_FIXNUM_P(rubyVal))
            let back = RB_FIX2LONG(rubyVal)
            XCTAssertEqual(val, back)
            if val > 0 {
                let back_unsigned = RB_FIX2ULONG(rubyVal)
                XCTAssertEqual(UInt(val), back_unsigned)
            }
        }
        XCTAssertFalse(RB_FIXABLE(Int.max))
    }
}
