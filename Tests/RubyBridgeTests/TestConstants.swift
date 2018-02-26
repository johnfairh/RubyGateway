//
//  TestConstants.swift
//  RubyBridgeTests
//
//  Distributed under the MIT license, see LICENSE
//

import XCTest
@testable import RubyBridge

/// Ruby constant access
class TestConstants: XCTestCase {

    func testConstantAccess() {
        do {
            let _ = try Ruby.require(filename: Helpers.fixturePath("nesting.rb"))

            let outerModule = try Ruby.getConstant("Outer")
            XCTAssertEqual(.T_MODULE, TYPE(outerModule.rubyValue))

            let outerConstant = try outerModule.getConstant("OUTER_CONSTANT")
            XCTAssertEqual(.T_FIXNUM, TYPE(outerConstant.rubyValue))
        } catch {
            XCTFail("Unexpected exception: \(error)")
        }
    }

    func testNestedConstantAccess() {
        do {
            let _ = try Ruby.require(filename: Helpers.fixturePath("nesting.rb"))

            let innerClass = try Ruby.getClass("Outer::Middle::Inner")
            XCTAssertEqual(.T_CLASS, TYPE(innerClass.rubyValue))
        } catch {
            XCTFail("Unexpected exception: \(error)")
        }
    }

    func testPopupConstantAccess() {
        do {
            let _ = try Ruby.require(filename: Helpers.fixturePath("nesting.rb"))

            let innerClass = try Ruby.getClass("Outer::Middle::Inner")

            let _ = try innerClass.getConstant("Outer")
        } catch {
            XCTFail("Unexpected exception: \(error)")
        }
    }

    func testFailedConstantAccess() {
        do {
            let _ = try Ruby.require(filename: Helpers.fixturePath("nesting.rb"))

            let outerModule = try Ruby.getConstant("Fish")
            XCTFail("Managed to find 'Fish' constant: \(outerModule)")
        } catch {
        }

        let middleModule = try! Ruby.getConstant("Outer::Middle")
        do {
            let outerModule = try middleModule.getConstant("Outer::Inner")
            XCTFail("Constant scope resolved weirdly - \(outerModule)")
        } catch {
        }

        do {
            let innerConstant = try Ruby.getConstant("Outer::Middle::Fish")
            XCTFail("Managed to find 'Fish' constant: \(innerConstant)")
        } catch {
        }
    }

    func testNotAClass() {
        do {
            let _ = try Ruby.require(filename: Helpers.fixturePath("nesting.rb"))

            let notClass = try Ruby.getClass("Outer")
            XCTFail("Managed to get a class for module Outer: \(notClass)")
        } catch RbError.notClass(_) {
            // OK
        } catch {
            XCTFail("Unexpected exception \(error)")
        }
    }

    static var allTests = [
        ("testConstantAccess", testConstantAccess),
        ("testNestedConstantAccess", testNestedConstantAccess),
        ("testPopupConstantAccess", testPopupConstantAccess),
        ("testFailedConstantAccess", testFailedConstantAccess),
        ("testNotAClass", testNotAClass)
    ]
}
