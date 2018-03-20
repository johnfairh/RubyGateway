//
//  TestConstants.swift
//  RubyGatewayTests
//
//  Distributed under the MIT license, see LICENSE
//

import XCTest
import RubyGateway

/// Ruby constant access
class TestConstants: XCTestCase {

    func testConstantAccess() {
        do {
            let _ = try Ruby.require(filename: Helpers.fixturePath("nesting.rb"))

            let outerModule = try Ruby.getConstant("Outer")
            XCTAssertEqual(.T_MODULE, outerModule.rubyType)

            let outerConstant = try outerModule.getConstant("OUTER_CONSTANT")
            XCTAssertEqual(.T_FIXNUM, outerConstant.rubyType)
        } catch {
            XCTFail("Unexpected exception: \(error)")
        }
    }

    private func testBadName(_ name: String) {
        do {
            let const = try Ruby.getConstant(name)
            XCTFail("Managed to find constant called '\(name)': \(const)")
        } catch RbError.badIdentifier(_, let id) {
            XCTAssertEqual(name, id)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testConstantName() {
        testBadName("lowercase")
        testBadName("")
    }

    func testNestedConstantAccess() {
        do {
            let _ = try Ruby.require(filename: Helpers.fixturePath("nesting.rb"))

            let innerClass = try Ruby.getClass("Outer::Middle::Inner")
            XCTAssertEqual(.T_CLASS, innerClass.rubyType)
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
        } catch RbError.badType(_) {
            // OK
        } catch {
            XCTFail("Unexpected exception \(error)")
        }
    }

    static var allTests = [
        ("testConstantAccess", testConstantAccess),
        ("testConstantName", testConstantName),
        ("testNestedConstantAccess", testNestedConstantAccess),
        ("testPopupConstantAccess", testPopupConstantAccess),
        ("testFailedConstantAccess", testFailedConstantAccess),
        ("testNotAClass", testNotAClass)
    ]
}
