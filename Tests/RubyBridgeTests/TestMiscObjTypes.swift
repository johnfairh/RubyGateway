//
//  TestMiscObjTypes.swift
//  RubyGatewayTests
//
//  Distributed under the MIT license, see LICENSE
//

import CRuby
@testable /* various macros */ import RubyBridge
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

    // Used to support ExpressibleAsNilLiteral but turns out is not so useful
    // and docs say not to do so... 
    func testNilLiteralPromotion() {
        let obj: RbObject = RbObject.nilObject
        XCTAssertFalse(obj.isTruthy)
        XCTAssertTrue(obj.isNil)
        obj.withRubyValue { rubyVal in
            XCTAssertEqual(Qnil, rubyVal)
        }
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

    func testSymbols() {
        let sym = RbSymbol("name")
        XCTAssertEqual("RbSymbol(name)", sym.description)
        let obj = sym.rubyObject
        XCTAssertEqual(.T_SYMBOL, obj.rubyType)

        if let backSym = RbSymbol(obj) {
            XCTFail("Managed to create symbol from object: \(backSym)")
        }
    }

    static var allTests = [
        ("testNilConstants", testNilConstants),
        ("testNilLiteralPromotion", testNilLiteralPromotion),
        ("testBoolRoundTrip", testBoolRoundTrip),
        ("testFailedBoolConversion", testFailedBoolConversion),
        ("testBoolLiteralPromotion", testBoolLiteralPromotion),
        ("testSymbols", testSymbols)
    ]
}
