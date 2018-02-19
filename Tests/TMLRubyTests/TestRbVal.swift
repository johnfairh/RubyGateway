//
//  TestRbVal.swift
//  TMLRubyTests
//
//  Created by John Fairhurst on 19/02/2018.
//

import XCTest
import CRuby
@testable import TMLRuby

/// Core Val tests
class TestRbVal: XCTestCase {

    override class func setUp() {
        let _ = Helpers.ruby
    }

    func testSimple() {
        let rbValue = Qtrue
        let val = RbVal(rubyValue: rbValue)
        XCTAssertEqual(rbValue, val.rubyValue)
    }

    // Try and test the GC-safe thing works.
    // Probably a bit pointless, the value is probably on the stack,
    // but at least tests that the gc registration doesn't hurt.

    private func getRubyNum(_ u: UInt) -> RbVal {
        return RbVal(rubyValue: RB_ULONG2NUM(u))
    }

    func testObject() {
        let testNum = UInt.max // will not fit in FIXNUM, Ruby heap allocation
        let val = getRubyNum(testNum)
        rb_gc()
        let backVal = RB_NUM2ULONG(val.rubyValue)
        XCTAssertEqual(testNum, backVal)
    }

    func testCopy() {
        let testNum = UInt.max
        let rbVal2: RbVal
        do {
            let rbVal1 = RbVal(rubyValue: RB_ULONG2NUM(testNum))
            rbVal2 = RbVal(rbVal1)
        }
        let backVal = RB_NUM2ULONG(rbVal2.rubyValue)
        XCTAssertEqual(testNum, backVal)
    }

    static var allTests = [
        ("testSimple", testSimple),
        ("testObject", testObject),
        ("testCopy", testCopy)
    ]
}
