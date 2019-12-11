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
        doErrorFree {
            let _ = try Ruby.require(filename: Helpers.fixturePath("nesting.rb"))

            let outerModule = try Ruby.getConstant("Outer")
            XCTAssertEqual(.T_MODULE, outerModule.rubyType)

            let outerConstant = try outerModule.getConstant("OUTER_CONSTANT")
            XCTAssertEqual(.T_FIXNUM, outerConstant.rubyType)
        }
    }

    private func testBadName(_ name: String) {
        doErrorFree {
            do {
                let const = try Ruby.getConstant(name)
                XCTFail("Managed to find constant called '\(name)': \(const)")
            } catch RbError.badIdentifier(_, let id) {
                XCTAssertEqual(name, id)
            }
        }
    }

    func testConstantName() {
        testBadName("lowercase")
        testBadName("")
        testBadName("::")
    }

    func testNestedConstantAccess() {
        doErrorFree {
            let _ = try Ruby.require(filename: Helpers.fixturePath("nesting.rb"))

            let innerClass = try Ruby.getClass("Outer::Middle::Inner")
            XCTAssertEqual(.T_CLASS, innerClass.rubyType)
        }
    }

    func testPopupConstantAccess() {
        doErrorFree {
            let _ = try Ruby.require(filename: Helpers.fixturePath("nesting.rb"))

            let innerClass = try Ruby.getClass("Outer::Middle::Inner")

            let _ = try innerClass.getConstant("Outer")
        }
    }

    func testFailedConstantAccess() {
        doError {
            let _ = try Ruby.require(filename: Helpers.fixturePath("nesting.rb"))

            let outerModule = try Ruby.getConstant("Fish")
            XCTFail("Managed to find 'Fish' constant: \(outerModule)")
        }

        let middleModule = try! Ruby.getConstant("Outer::Middle")
        doError {
            let outerModule = try middleModule.getConstant("Outer::Inner")
            XCTFail("Constant scope resolved weirdly - \(outerModule)")
        }

        doError {
            let innerConstant = try Ruby.getConstant("Outer::Middle::Fish")
            XCTFail("Managed to find 'Fish' constant: \(innerConstant)")
        }
    }

    func testNotAClass() {
        doErrorFree {
            do {
                let _ = try Ruby.require(filename: Helpers.fixturePath("nesting.rb"))

                let notClass = try Ruby.getClass("Outer")
                XCTFail("Managed to get a class for module Outer: \(notClass)")
            } catch RbError.badType(_) {
                // OK
            }
        }
    }

    func testSetTop() {
        doErrorFree {
            let constName = "NU_CONST"
            let constVal = 48

            try Ruby.setConstant(constName, newValue: constVal)

            let readConst = try Ruby.getConstant(constName)
            XCTAssertEqual(constVal, Int(readConst))
        }
    }

    func testSetNested() {
        doErrorFree {
            try Ruby.require(filename: Helpers.fixturePath("nesting.rb"))

            let midModule = try Ruby.get("Outer::Middle")

            let constName = "INNER_CONSTANT_2"
            let constVal = "Peace"

            let setVal = try midModule.setConstant("Inner::\(constName)", newValue: constVal)
            XCTAssertEqual(constVal, String(setVal))

            let rbReadVal = try Ruby.eval(ruby: "Outer::Middle::Inner::\(constName)")
            XCTAssertEqual(constVal, String(rbReadVal))
        }
    }

    func testSetErrors() {
        doError {
            try Ruby.setConstant("unConstantName", newValue: 22)
            XCTFail("Created badly named constant")
        }

        doError {
            try Ruby.setConstant("Imaginary::Constant", newValue: 22)
            XCTFail("Created badly namedspaced constant")
        }

        let obj = RbObject(22)
        doError {
            try obj.setConstant("SomeConstant", newValue: 22)
            XCTFail("Created constant inside non-class object")
        }
    }

    static var allTests = [
        ("testConstantAccess", testConstantAccess),
        ("testConstantName", testConstantName),
        ("testNestedConstantAccess", testNestedConstantAccess),
        ("testPopupConstantAccess", testPopupConstantAccess),
        ("testFailedConstantAccess", testFailedConstantAccess),
        ("testNotAClass", testNotAClass),
        ("testSetTop", testSetTop),
        ("testSetNested", testSetNested)
    ]
}
