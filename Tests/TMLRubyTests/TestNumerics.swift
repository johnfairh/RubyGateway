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

    override class func setUp() {
        let _ = Helpers.ruby
    }

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

    /// Proper 'num' round-tripping -- Int
    func testIntNumRoundtrip() {
        let values = [Int.min, 0, Int.max]
        values.forEach { val in
            let rubyValue = RB_LONG2NUM(val)
            let swiftVal  = RB_NUM2LONG(rubyValue)
            XCTAssertEqual(val, swiftVal)
        }
    }

    /// Again, UInt
    func testUIntNumRoundtrip() {
        let values = [UInt.min, 0, UInt.max]
        values.forEach { val in
            let rubyValue = RB_ULONG2NUM(val)
            let swiftVal  = RB_NUM2ULONG(rubyValue)
            XCTAssertEqual(val, swiftVal)
        }
    }

    /// Proper 'num' round-tripping -- Int16
    func testInt16NumRoundtrip() {
        let values = [Int16.min, 0, Int16.max]
        values.forEach { val in
            let rubyValue = RB_SHORT2NUM(val)
            let swiftVal  = RB_NUM2SHORT(rubyValue)
            XCTAssertEqual(val, swiftVal)
        }
    }

    /// Proper 'num' round-tripping -- UInt16
    func testUInt16NumRoundtrip() {
        let values = [UInt16.min, 0, UInt16.max]
        values.forEach { val in
            let rubyValue = RB_USHORT2NUM(val)
            let swiftVal  = RB_NUM2USHORT(rubyValue)
            XCTAssertEqual(val, swiftVal)
        }
    }

    /// Proper 'num' round-tripping -- Int32
    func testInt32NumRoundtrip() {
        let values = [Int32.min, 0, Int32.max]
        values.forEach { val in
            let rubyValue = RB_INT2NUM(val)
            let swiftVal  = RB_NUM2INT(rubyValue)
            XCTAssertEqual(val, swiftVal)
        }
    }

    /// Proper 'num' round-tripping -- UInt32
    func testUInt32NumRoundtrip() {
        let values = [UInt32.min, 0, UInt32.max]
        values.forEach { val in
            let rubyValue = RB_UINT2NUM(val)
            let swiftVal  = RB_NUM2UINT(rubyValue)
            XCTAssertEqual(val, swiftVal)
        }
    }

    /// Proper 'num' round-tripping -- Int64
    func testInt64NumRoundtrip() {
        let values = [Int64.min, 0, Int64.max]
        values.forEach { val in
            let rubyValue = LL2NUM(val)
            let swiftVal  = RB_NUM2LL(rubyValue)
            XCTAssertEqual(val, swiftVal)
        }
    }

    /// Proper 'num' round-tripping -- UInt64
    func testUInt64NumRoundtrip() {
        let values = [UInt64.min, 0, UInt64.max]
        values.forEach { val in
            let rubyValue = ULL2NUM(val)
            let swiftVal  = RB_NUM2ULL(rubyValue)
            XCTAssertEqual(val, swiftVal)
        }
    }

    /// Floating point
    func testDoubleRoundtrip() {
        let values = [Double.leastNormalMagnitude,
                      Double.leastNonzeroMagnitude,
                      0.0,
                      Double.greatestFiniteMagnitude,
                      Double.nan,
                      Double.signalingNaN,
                      Double.infinity]
        values.forEach { val in
            let rubyValue = DBL2NUM(val)
            XCTAssertTrue(RB_FLOAT_TYPE_P(rubyValue))
            XCTAssertTrue(!RB_FLONUM_P(rubyValue) || val == 0.0)
            let swiftVal  = NUM2DBL(rubyValue)
            XCTAssertTrue((val.isNaN && swiftVal.isNaN) ||
                          (val == swiftVal))
        }
    }
}
