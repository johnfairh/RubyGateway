//
//  TestRbVal.swift
//  RubyBridgeTests
//
//  Distributed under the MIT license, see LICENSE
//

import XCTest
import CRuby
@testable /* Qtrue */ import RubyBridge

/// Core object tests
class TestRbObject: XCTestCase {
    // obj construction
    func testSimple() {
        let rbValue = Qtrue
        let obj = RbObject(rubyValue: rbValue)
        XCTAssertEqual(rbValue, obj.rubyValue)
        XCTAssertTrue(obj === obj.rubyObject)
        var called = false
        obj.withRubyValue { val in
            XCTAssertEqual(rbValue, val)
            called = true
        }
        XCTAssertTrue(called)
    }

    // Try and test the GC-safe thing works.
    // Probably a bit pointless, the value is probably on the stack,
    // but at least tests that the gc registration doesn't hurt.

    func testObject() {
        let obj = RbObject(UInt.max)
        rb_gc()
        rb_gc()
        rb_gc()
        rb_gc()
        let backVal = UInt(obj)
        XCTAssertEqual(UInt.max, backVal)
    }

    func testCopy() {
        let testNum = UInt.max
        let rbObj2: RbObject
        do {
            let rbObj1 = RbObject(testNum)
            rbObj2 = RbObject(rbObj1)
        }
        let backVal = UInt(rbObj2)
        XCTAssertEqual(testNum, backVal)
    }

    // trivial conversions
    func testConversions() {
        let string = "Test String"
        let rubyObj = RbObject(string)
        XCTAssertEqual(string, rubyObj.description)

        let playgroundQL = rubyObj.customPlaygroundQuickLook
        switch playgroundQL {
        case let .text(str): XCTAssertEqual(string, str)
        default: XCTFail("Unexpected playgroundquicklookable: \(playgroundQL)")
        }
    }

    // inspect
    func testInspect() {
        try! Ruby.require(filename: Helpers.fixturePath("inspectables.rb"))
        guard let uninspectable = RbObject(ofClass: "Uninspectable") else {
            XCTFail("Couldn't create object")
            return
        }
        XCTAssertEqual("[Indescribable]", uninspectable.debugDescription)

        guard let inspectable = RbObject(ofClass: "Inspectable") else {
            XCTFail("Couldn't create object")
            return
        }
        print(inspectable.debugDescription)
    }

    // new helper (goodpath covered elsewhere)
    func testNewInstance() {
        if let obj = RbObject(ofClass: "DoesNotExist") {
            XCTFail("Managed to create object of odd class: \(obj)")
        }
    }

    static var allTests = [
        ("testSimple", testSimple),
        ("testObject", testObject),
        ("testCopy", testCopy),
        ("testConversions", testConversions),
        ("testInspect", testInspect),
        ("testNewInstance", testNewInstance)
    ]
}
