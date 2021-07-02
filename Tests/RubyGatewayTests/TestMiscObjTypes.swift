//
//  TestMiscObjTypes.swift
//  RubyGatewayTests
//
//  Distributed under the MIT license, see LICENSE
//

import CRuby
@testable /* various macros */ import RubyGateway
import RubyGatewayHelpers
import XCTest

/// Misc data type tests
class TestMiscObjTypes: XCTestCase {

    func testNilConstants() {
        let nilVal = Qnil
        let falseVal = Qfalse
        let trueVal = Qtrue

        XCTAssertTrue(rbg_RB_NIL_P(nilVal) != 0)
        XCTAssertFalse(rbg_RB_NIL_P(falseVal) != 0)
        XCTAssertFalse(rbg_RB_NIL_P(trueVal) != 0)

        XCTAssertFalse(rbg_RB_TEST(nilVal) != 0)
        XCTAssertFalse(rbg_RB_TEST(falseVal) != 0)
        XCTAssertTrue(rbg_RB_TEST(trueVal) != 0)

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

    func testHashableSymbols() {
        let h1 = [RbSymbol("one"): "One", RbSymbol("two"): "Two"]
        let h2 = [RbSymbol("one").rubyObject: "One", RbSymbol("two").rubyObject: "Two"]

        let rh1 = h1.rubyObject
        let rh2 = h2.rubyObject
        XCTAssertEqual(rh1, rh2)
    }

    func testBadCoerce() {
        doErrorFree {
            let obj = RbObject("string")

            doError {
                let a: Int = try obj.convert()
                XCTFail("Managed to convert string to int: \(a)")
            }

            doError {
                let a = try obj.convert(to: Int.self)
                XCTFail("Managed to convert string to int: \(a)")
            }
        }
    }
}
