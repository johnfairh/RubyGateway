//
//  TestStrings.swift
//  RubyGatewayTests
//
//  Distributed under the MIT license, see LICENSE
//

import XCTest
import RubyGateway
import CRuby

/// Tests for String helpers
class TestStrings: XCTestCase {

    private func doTestRoundTrip(_ string: String) {
        let rubyObj = RbObject(string)
        XCTAssertEqual(.T_STRING, rubyObj.rubyType)

        guard let backString = String(rubyObj) else {
            XCTFail("Oops, to_s failed??")
            return
        }
        XCTAssertEqual(string, backString)
    }

    func testEmpty() {
        doTestRoundTrip("")
    }

    func testAscii() {
        doTestRoundTrip("A test string")
    }

    func testUtf8() {
        doTestRoundTrip("abë🐽🇧🇷end")
    }

    func testUtf8WithNulls() {
        doTestRoundTrip("abë\0🐽🇧🇷en\0d")
    }

    func testFailedStringConversion() {
        try! Ruby.require(filename: Helpers.fixturePath("nonconvert.rb"))

        guard let instance = RbObject(ofClass: "Nonconvert") else {
            XCTFail("Couldn't create object")
            return
        }
        XCTAssertEqual(.T_OBJECT, instance.rubyType)
        
        if let str = String(instance) {
            XCTFail("Converted unconvertible: \(str)")
        }
        let descr = instance.description
        XCTAssertNotEqual("", descr)
    }

    // to_s, to_str, priority
    func testConversion() {
        doErrorFree {
            try Ruby.require(filename: Helpers.fixturePath("nonconvert.rb"))

            guard let i1 = RbObject(ofClass: "JustToS"),
                let i2 = RbObject(ofClass: "BothToSAndToStr") else {
                    XCTFail("Couldn't create objects")
                    return
            }

            let _ = try i1.convert(to: String.self)
            let s2 = try i2.convert(to: String.self)
            
            XCTAssertEqual("to_str", s2)
        }
    }

    func testLiteralPromotion() {
        let obj: RbObject = "test string"
        XCTAssertEqual("test string", String(obj))
    }
}
