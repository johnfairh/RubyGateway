//
//  TestMiscObjTypes.swift
//  RubyBridgeTests
//
//  Distributed under the MIT license, see LICENSE
//

import CRuby
@testable import RubyBridge
import XCTest

/// Misc data type tests
class TestMiscObjTypes: XCTestCase {

    func testNilConstants() {
        let nilVal = Qnil
        let falseVal = Qfalse
        let trueVal = Qtrue

        XCTAssertTrue(RB_NIL_P(nilVal))
        XCTAssertFalse(RB_NIL_P(falseVal))
        XCTAssertFalse(RB_NIL_P(trueVal))

        XCTAssertFalse(RB_TEST(nilVal))
        XCTAssertFalse(RB_TEST(falseVal))
        XCTAssertTrue(RB_TEST(trueVal))

        XCTAssertEqual(.T_NIL, TYPE(nilVal))
        XCTAssertEqual(.T_FALSE, TYPE(falseVal))
        XCTAssertEqual(.T_TRUE, TYPE(trueVal))
    }

    func testNilLiteralPromotion() {
        let obj: RbObject = nil
        XCTAssertFalse(obj.isTruthy)
        XCTAssertTrue(obj.isNil)
        XCTAssertEqual(Qnil, obj.rubyValue)
    }

    private func doTestBoolRoundTrip(_ val: Bool) {
        let obj = RbObject(val)
        XCTAssertTrue(obj.rubyType == .T_FALSE || obj.rubyType == .T_TRUE)
        guard let bool = Bool(obj) else {
            XCTFail("Couldn't convert boolean value")
            return
        }
        XCTAssertEqual(val, bool)
    }

    func testBoolRoundTrip() {
        doTestBoolRoundTrip(true)
        doTestBoolRoundTrip(false)
    }

    func testFailedBoolConversion() {
        let obj = RbObject(rubyValue: Qundef)
        if let bool = Bool(obj) {
            XCTFail("Converted undef to bool - \(bool)")
        }
    }

    func testBoolLiteralPromotion() {
        let trueObj: RbObject = true
        let falseObj: RbObject = false

        XCTAssertEqual(.T_TRUE, trueObj.rubyType)
        XCTAssertEqual(.T_FALSE, falseObj.rubyType)
    }

    static var allTests = [
        ("testNilConstants", testNilConstants),
        ("testNilLiteralPromotion", testNilLiteralPromotion),
        ("testBoolRoundTrip", testBoolRoundTrip),
        ("testFailedBoolConversion", testFailedBoolConversion),
        ("testBoolLiteralPromotion", testBoolLiteralPromotion)
    ]
}
