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

    func testPopupConstantAccess() {
        do {
            let _ = try Ruby.require(filename: Helpers.fixturePath("nesting.rb"))

            let innerClass = try Ruby.getClass(name: "Outer::Middle::Inner")

            let _ = try innerClass.getConstant(name: "Outer")
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
            let outerModule = try middleModule.getConstant(name: "Outer::Inner")
            XCTFail("Constant scope resolved weirdly - \(outerModule)")
        } catch {
        }

        do {
            let innerConstant = try Ruby.getConstant(name: "Outer::Middle::Fish")
            XCTFail("Managed to find 'Fish' constant: \(innerConstant)")
        } catch {
        }
    }

    func testNotAClass() {
        do {
            let _ = try Ruby.require(filename: Helpers.fixturePath("nesting.rb"))

            let notClass = try Ruby.getClass(name: "Outer")
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
