//
//  TestRbVal.swift
//  RubyGatewayTests
//
//  Distributed under the MIT license, see LICENSE
//

import XCTest
import CRuby
@testable /* Qtrue */ import RubyGateway

/// Core object tests
class TestRbObject: XCTestCase {
    // obj construction
    func testSimple() {
        let rbValue = Qtrue
        let obj = RbObject(rubyValue: rbValue)
        obj.withRubyValue { rubyValue in
            XCTAssertEqual(rbValue, rubyValue)
        }
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

        if let obj = RbObject(ofClass: "DoesNotExist", retainBlock: false, blockCall: { args in .nilObject }) {
            XCTFail("Managed to create object of odd class: \(obj)")
        }
    }

    // symbol helper
    func testSymbols() {
        let symName = "symname"
        let symbolObj = RbObject(RbSymbol(symName))
        XCTAssertEqual(.T_SYMBOL, symbolObj.rubyType)

        XCTAssertEqual(symName, symbolObj.description)

        symbolObj.withRubyValue { symValue in
            let strObj = RbObject(rubyValue: rb_sym2str(symValue))
            XCTAssertEqual(symName, String(strObj))
        }
    }

    // hashable
    func testHashing() {
        let objs: [RbObject] = [123.4, 0, "str"]
        objs.forEach { obj in
            guard obj.hashValue != 0 else {
                XCTFail("Suspicious hashvalue 0")
                return
            }
        }
    }

    // comparable
    func testComparable() {
        let objneg = RbObject(Int.min)
        let objpos1 = RbObject(UInt.max)
        let objpos1copy = RbObject(objpos1)
        let objstr1 = RbObject("str")
        let objstr2 = RbObject("utr")

        XCTAssertTrue(objneg == objneg)
        XCTAssertFalse(objneg == objpos1)
        XCTAssertTrue(objpos1 == objpos1copy)
        XCTAssertFalse(objneg == objstr1)

        XCTAssertTrue(objneg < objpos1)
        XCTAssertFalse(objpos1 < objpos1)
        XCTAssertTrue(objstr1 < objstr2)
    }

    // assoc objects
    static var testObjDeinitCount = 0

    class TestObj {
        private let name: String
        init(_ name: String) {
            self.name = name
        }
        deinit {
            TestRbObject.testObjDeinitCount += 1
        }
    }

    func testAssociatedObjects() {
        var obj: RbObject? = RbObject(24)
        TestRbObject.testObjDeinitCount = 0
        do {
            let t1 = TestObj("a")
            obj?.associate(object: t1)

            let t2 = TestObj("b")
            obj?.associate(object: t2)
        }
        XCTAssertEqual(0, TestRbObject.testObjDeinitCount)
        obj = nil
        XCTAssertEqual(2, TestRbObject.testObjDeinitCount)
    }

    static var allTests = [
        ("testSimple", testSimple),
        ("testObject", testObject),
        ("testCopy", testCopy),
        ("testConversions", testConversions),
        ("testInspect", testInspect),
        ("testNewInstance", testNewInstance),
        ("testSymbols", testSymbols),
        ("testHashing", testHashing),
        ("testComparable", testComparable),
        ("testAssociatedObjects", testAssociatedObjects)
    ]
}
