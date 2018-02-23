//
//  TestRbVal.swift
//  RubyBridgeTests
//
//  Distributed under the MIT license, see LICENSE
//

import XCTest
import CRuby
@testable import RubyBridge

/// Core Val tests
class TestRbVal: XCTestCase {

    override class func setUp() {
        Helpers.initRuby()
    }

    func testSimple() {
        let rbValue = Qtrue
        let obj = RbObject(rubyValue: rbValue)
        XCTAssertEqual(rbValue, obj.rubyValue)
        XCTAssertTrue(obj === obj.rubyObject)
    }

    // Try and test the GC-safe thing works.
    // Probably a bit pointless, the value is probably on the stack,
    // but at least tests that the gc registration doesn't hurt.

    func testObject() {
        let obj = RbObject(UInt.max)
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

    static var allTests = [
        ("testSimple", testSimple),
        ("testObject", testObject),
        ("testCopy", testCopy)
    ]
}
