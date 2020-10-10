//
//  TestDynamic.swift
//  RubyGatewayTests
//
//  Distributed under the MIT license, see LICENSE
//

import XCTest
import RubyGateway

// Tests for dynamic member function
class TestDynamic: XCTestCase {

    /// Getter
    func testDynamicMemberLookupRead() {
        doErrorFree {
            try Ruby.require(filename: Helpers.fixturePath("methods.rb"))

            guard let obj = RbObject(ofClass: "MethodsTest") else {
                XCTFail("Couldn't create object")
                return
            }

            guard let strObj = obj.property else {
                XCTFail("Couldn't access member 'property'")
                return
            }

            XCTAssertEqual("Default", String(strObj))

            if let mysterious = obj.not_a_member {
                XCTFail("Accessed not_a_member: \(mysterious)")
                return
            }
        }
    }

    /// Write
    func testDynamicMemberLookupWrite() {
        doErrorFree {
            try Ruby.require(filename: Helpers.fixturePath("methods.rb"))

            guard let obj = RbObject(ofClass: "MethodsTest") else {
                XCTFail("Couldn't create object")
                return
            }

            let newValue = "Changed it!"
            obj.property = RbObject(newValue)

            guard let strObj = obj.property else {
                XCTFail("Couldn't access member 'property'")
                return
            }

            XCTAssertEqual(newValue, String(strObj))

            RbError.history.clear()
            obj.bad_property = RbObject(23)
            XCTAssertNotNil(RbError.history.mostRecent)

            RbError.history.clear()
            obj.property = nil
            XCTAssertEqual(.nilObject, obj.property)
        }
    }

    static var allTests = [
        ("testDynamicMemberLookupRead", testDynamicMemberLookupRead),
        ("testDynamicMemberLookupWrite", testDynamicMemberLookupWrite),
    ]
}
