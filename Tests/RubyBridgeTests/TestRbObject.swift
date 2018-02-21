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
    }

    // Try and test the GC-safe thing works.
    // Probably a bit pointless, the value is probably on the stack,
    // but at least tests that the gc registration doesn't hurt.

    private func getRubyNum(_ u: UInt) -> RbObject {
        return RbObject(rubyValue: RB_ULONG2NUM(u))
    }

    func testObject() {
        let testNum = UInt.max // will not fit in FIXNUM, Ruby heap allocation
        let obj = getRubyNum(testNum)
        rb_gc()
        let backVal = RB_NUM2ULONG(obj.rubyValue)
        XCTAssertEqual(testNum, backVal)
    }

    func testCopy() {
        let testNum = UInt.max
        let rbObj2: RbObject
        do {
            let rbObj1 = RbObject(rubyValue: RB_ULONG2NUM(testNum))
            rbObj2 = RbObject(rbObj1)
        }
        let backVal = RB_NUM2ULONG(rbObj2.rubyValue)
        XCTAssertEqual(testNum, backVal)
    }

    static var allTests = [
        ("testSimple", testSimple),
        ("testObject", testObject),
        ("testCopy", testCopy)
    ]
}
