//
//  TestConstants.swift
//  RubyBridgeTests
//
//  Distributed under the MIT license, see LICENSE
//

import XCTest
@testable import RubyBridge

/// Constants - fundamental and high-level ones
class TestConstants: XCTestCase {

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

    func testConstantAccess() {
        do {
            let _ = try Ruby.require(filename: Helpers.fixturePath("nesting.rb"))

            let outerModule = try Ruby.getConstant(name: "Outer")
            XCTAssertEqual(.T_MODULE, TYPE(outerModule.rubyValue))

            let outerConstant = try outerModule.getConstant(name: "OUTER_CONSTANT")
            XCTAssertEqual(.T_FIXNUM, TYPE(outerConstant.rubyValue))
        } catch {
            XCTFail("Unexpected exception: \(error)")
        }
    }

    func testNestedConstantAccess() {
        do {
            let _ = try Ruby.require(filename: Helpers.fixturePath("nesting.rb"))

            let innerClass = try Ruby.getClass(name: "Outer::Middle::Inner")
            XCTAssertEqual(.T_CLASS, TYPE(innerClass.rubyValue))
        } catch {
            XCTFail("Unexpected exception: \(error)")
        }
    }

    func testFailedConstantAccess() {
        do {
            let _ = try Ruby.require(filename: Helpers.fixturePath("nesting.rb"))

            let outerModule = try Ruby.getConstant(name: "Fish")
            XCTFail("Managed to find 'Fish' constant: \(outerModule)")
        } catch {
        }

        let middleModule = try! Ruby.getConstant(name: "Outer::Middle")
        do {
            let outerModule = try middleModule.getConstant(name: "Outer")
            XCTFail("Constant scope resolved upwards - \(outerModule)")
        } catch {
        }

        do {
            let innerConstant = try Ruby.getConstant(name: "Outer::Middle::Fish")
            XCTFail("Managed to find 'Fish' constant: \(innerConstant)")
        } catch {
        }
    }

    static var allTests = [
        ("testNilConstants", testNilConstants),
        ("testConstantAccess", testConstantAccess),
        ("testNestedConstantAccess", testNestedConstantAccess),
        ("testFailedConstantAccess", testFailedConstantAccess)
    ]
}
