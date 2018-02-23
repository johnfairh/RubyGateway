//
//  TestNumerics.swift
//  RubyBridgeTests
//
//  Distributed under the MIT license, see LICENSE
//

import XCTest
@testable import RubyBridge

/// A bunch of the Ruby numeric conversion macros don't make it through
/// the importer so are re-implemented in various ways.  These tests check
/// they're OK.
class TestNumerics: XCTestCase {

    override class func setUp() {
        Helpers.initRuby()
    }

    /// Check we can round-trip values through fixnum, that our
    /// understanding matches Ruby's.
    func testFixnumRoundtrip() {
        let values = [RUBY_FIXNUM_MIN, 0, RUBY_FIXNUM_MAX]
        values.forEach { val in
            XCTAssertTrue(RB_FIXABLE(val))
            let rubyVal = RB_LONG2FIX(val)
            XCTAssertTrue(RB_FIXNUM_P(rubyVal))
            XCTAssertTrue(RB_TYPE_P(rubyVal, .T_FIXNUM))
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
            let rubyObj = RbObject(val)
            let swiftVal = Int(rubyObj)
            XCTAssertEqual(val, swiftVal)
        }
    }

    /// Again, UInt
    func testUIntNumRoundtrip() {
        let values = [UInt.min, 0, UInt.max]
        values.forEach { val in
            let rubyObj  = RbObject(val)
            let swiftVal = UInt(rubyObj)
            XCTAssertEqual(val, swiftVal)
        }
    }

    // Unsigned negative conversion failures
    func testUIntNegativeUnconvertible() {
        let negativeObjects = [ RbObject(rubyValue: RB_LONG2NUM(-2)),
                                RbObject(rubyValue: RB_LONG2NUM(Int.min)),
                                RbObject(rubyValue: DBL2NUM(-4.0))]
        negativeObjects.forEach { obj in
            if let num = UInt(obj) {
                XCTFail("Managed to convert \(obj) to unsigned: \(num)")
            }
        }
    }

    /// Proper 'num' round-tripping -- Int8
    func testInt8NumRoundtrip() {
        let values = [Int8.min, 0, Int8.max]
        values.forEach { val in
            let rubyObj = RbObject(val)
            let swiftVal = Int8(rubyObj)
            XCTAssertEqual(val, swiftVal)
        }
    }

    /// Proper 'num' round-tripping -- UInt8
    func testUInt8NumRoundtrip() {
        let values = [UInt8.min, 0, UInt8.max]
        values.forEach { val in
            let rubyObj = RbObject(val)
            let swiftVal = UInt8(rubyObj)
            XCTAssertEqual(val, swiftVal)
        }
    }

    /// Proper 'num' round-tripping -- Int16
    func testInt16NumRoundtrip() {
        let values = [Int16.min, 0, Int16.max]
        values.forEach { val in
            let rubyObj = RbObject(val)
            let swiftVal = Int16(rubyObj)
            XCTAssertEqual(val, swiftVal)
        }
    }

    /// Proper 'num' round-tripping -- UInt16
    func testUInt16NumRoundtrip() {
        let values = [UInt16.min, 0, UInt16.max]
        values.forEach { val in
            let rubyObj = RbObject(val)
            let swiftVal = UInt16(rubyObj)
            XCTAssertEqual(val, swiftVal)
        }
    }

    /// Proper 'num' round-tripping -- Int32
    func testInt32NumRoundtrip() {
        let values = [Int32.min, 0, Int32.max]
        values.forEach { val in
            let rubyObj = RbObject(val)
            let swiftVal = Int32(rubyObj)
            XCTAssertEqual(val, swiftVal)
        }
    }

    /// Proper 'num' round-tripping -- UInt32
    func testUInt32NumRoundtrip() {
        let values = [UInt32.min, 0, UInt32.max]
        values.forEach { val in
            let rubyObj = RbObject(val)
            let swiftVal = UInt32(rubyObj)
            XCTAssertEqual(val, swiftVal)
        }
    }

    /// Proper 'num' round-tripping -- Int64
    func testInt64NumRoundtrip() {
        let values = [Int64.min, 0, Int64.max]
        values.forEach { val in
            let rubyObj = RbObject(val)
            let swiftVal = Int64(rubyObj)
            XCTAssertEqual(val, swiftVal)
        }
    }

    /// Proper 'num' round-tripping -- UInt64
    func testUInt64NumRoundtrip() {
        let values = [UInt64.min, 0, UInt64.max]
        values.forEach { val in
            let rubyObj = RbObject(val)
            let swiftVal = UInt64(rubyObj)
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
            let rubyObj = RbObject(val)
            XCTAssertTrue(!RB_FLONUM_P(rubyObj.rubyValue) || val == 0.0)
            guard let swiftVal = Double(rubyObj) else {
                XCTFail("Couldn't convert \(val) back to Swift")
                return
            }
            XCTAssertTrue((val.isNaN && swiftVal.isNaN) ||
                          (val == swiftVal))
        }
    }

    /// Floating point
    func testFloatRoundtrip() {
        let values = [Float.leastNormalMagnitude,
                      Float.leastNonzeroMagnitude,
                      Float(0.0),
                      Float.greatestFiniteMagnitude,
                      Float.nan,
                      Float.signalingNaN,
                      Float.infinity]
        values.forEach { val in
            let rubyObj = RbObject(val)
            XCTAssertTrue(RB_FLOAT_TYPE_P(rubyObj.rubyValue))
            guard let swiftVal = Float(rubyObj) else {
                XCTFail("Couldn't convert \(val) back to Swift")
                return
            }
            XCTAssertTrue((val.isNaN && swiftVal.isNaN) ||
                (val == swiftVal))
        }
    }

    // Number is too big to fit in 64 bits
    func testIntegerTooBig() {
        try! Ruby.require(filename: Helpers.fixturePath("numbers.rb"))

        let bigConstObj = try! Ruby.getConstant(name: "TestNumbers::BIG_NUM")

        if let num = UInt(bigConstObj) {
            XCTFail("Managed to express 2^80 in 64 bits: \(num)")
            return
        }

        if let num = UInt64(bigConstObj) {
            XCTFail("Managed to express 2^80 in 64 bits: \(num)")
            return
        }

        if let num = UInt32(bigConstObj) {
            XCTFail("Managed to express 2^80 in 32 bits: \(num)")
            return
        }

        if let num = UInt16(bigConstObj) {
            XCTFail("Managed to express 2^80 in 16 bits: \(num)")
            return
        }

        if let num = UInt8(bigConstObj) {
            XCTFail("Managed to express 2^80 in 8 bits: \(num)")
            return
        }

        if let num = Int(bigConstObj) {
            XCTFail("Managed to express 2^80 in 64 signed bits: \(num)")
            return
        }

        if let num = Int64(bigConstObj) {
            XCTFail("Managed to express 2^80 in 64 signed bits: \(num)")
            return
        }

        if let num = Int32(bigConstObj) {
            XCTFail("Managed to express 2^80 in 32 bits: \(num)")
            return
        }

        if let num = Int16(bigConstObj) {
            XCTFail("Managed to express 2^80 in 16 bits: \(num)")
            return
        }

        if let num = Int8(bigConstObj) {
            XCTFail("Managed to express 2^80 in 8 bits: \(num)")
            return
        }
    }

    // Object supports to_int but gives a negative number
    func testIntegerObjToNegative() {
        try! Ruby.require(filename: Helpers.fixturePath("numbers.rb"))

        let negaObjVal = try! Ruby.eval(ruby: "TestNumbers.new")
        let negaObj = RbObject(rubyValue: negaObjVal)

        if let num = UInt(negaObj) {
            XCTFail("Managed to convert object to a negative number to unsigned: \(num)")
        }
    }

    // Object has no to_f
    func testNoCustomFloatConversion() {
        try! Ruby.require(filename: Helpers.fixturePath("nonconvert.rb"))
        let instObj = RbObject(rubyValue: try! Ruby.eval(ruby: "Nonconvert.new"))
        if let dblNum = Double(instObj) {
            XCTFail("Managed to convert object to double: \(dblNum)")
        }
        if let flNum = Float(instObj) {
            XCTFail("Managed to convert object to float: \(flNum)")
        }
    }

    // String to_i, to_f accessible
    func testStringToNum() {
        let str = RbObject("123")

        guard let intFromStr = Int(str) else {
            XCTFail("Couldn't convert string to int")
            return
        }
        XCTAssertEqual(123, intFromStr)

        guard let dblFromStr = Double(str) else {
            XCTFail("Couldn't convert string to float")
            return
        }
        XCTAssertEqual(123.0, dblFromStr)
    }

    func testLiterals() {
        let val1: RbObject = 22
        let val2: RbObject = 4.14441

        XCTAssertEqual(.T_FIXNUM, val1.rubyType)
        XCTAssertTrue(RB_FLOAT_TYPE_P(val2.rubyValue))

        guard let swVal1 = UInt(val1), let swVal2 = Double(val2) else {
            XCTFail("Couldn't convert back to Swift")
            return
        }

        XCTAssertEqual(22, swVal1)
        XCTAssertEqual(4.14441, swVal2)
    }

    static var allTests = [
        ("testFixnumRoundtrip", testFixnumRoundtrip),
        ("testIntNumRoundtrip", testIntNumRoundtrip),
        ("testUIntNumRoundtrip", testUIntNumRoundtrip),
        ("testUIntNegativeUnconvertible", testUIntNegativeUnconvertible),
        ("testInt8NumRoundtrip", testInt8NumRoundtrip),
        ("testUInt8NumRoundtrip", testUInt8NumRoundtrip),
        ("testInt16NumRoundtrip", testInt16NumRoundtrip),
        ("testUInt16NumRoundtrip", testUInt16NumRoundtrip),
        ("testInt32NumRoundtrip", testInt32NumRoundtrip),
        ("testUInt32NumRoundtrip", testUInt32NumRoundtrip),
        ("testInt64NumRoundtrip", testInt64NumRoundtrip),
        ("testUInt64NumRoundtrip", testUInt64NumRoundtrip),
        ("testDoubleRoundtrip", testDoubleRoundtrip),
        ("testIntegerTooBig", testIntegerTooBig),
        ("testIntegerObjToNegative", testIntegerObjToNegative),
        ("testNoCustomFloatConversion", testNoCustomFloatConversion),
        ("testStringToNum", testStringToNum),
        ("testLiterals", testLiterals)
    ]
}
