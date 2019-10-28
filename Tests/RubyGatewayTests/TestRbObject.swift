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

        let playgroundDesc = rubyObj.playgroundDescription
        guard let playgroundDescStr = playgroundDesc as? String else {
            XCTFail("Not a string?")
            return
        }
        XCTAssertEqual(string, playgroundDescStr)
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

    // optional helper
    func testOptionalConformance() {
        let obj1 = Optional<RbObjectConvertible>(RbObject.nilObject)
        let obj2: Optional<RbObjectConvertible> = nil

        XCTAssertEqual(obj1?.rubyObject, obj2.rubyObject)
    }

    private func getMethodsTestHeapCount() throws -> Int {
        var count = 0
        try Ruby.get("ObjectSpace").call("each_object", args: [Ruby.getClass("MethodsTest")]) { args in
            count += 1
            return .nilObject
        }
        return count
    }

    private func runGC() throws {
        try Ruby.get("GC").call("start")
    }

    // Test RbObject alive prevents GC AND RbObject dead allows GC
    //
    // This test is very sensitive: it relies on Ruby being able to GC
    // the object that is created at point #1 by the time the call to
    // the GC at point #2 runs.
    //
    // This requires that Ruby cannot find a ref to the object somewhere
    // on the stack.  Over various Swift versions, parts of the implementation
    // have changed to make this harder and harder to track down: the structure
    // of the function is just 'what works' on latest.  Adding debugging prints
    // to places like `RbObject.deinit` tend to make the problem vanish because
    // argh.
    func testObjectGc() {
        var initialMTCount: Int = -1

        doErrorFree {
            try Ruby.require(filename: Helpers.fixturePath("methods.rb"))
            try runGC()
            initialMTCount = try getMethodsTestHeapCount()
        }

        doErrorFree {
            try runGC()

            do {
                let o = RbObject(ofClass: "MethodsTest")! // POINT #1

                XCTAssertEqual(initialMTCount + 1, try getMethodsTestHeapCount())
                print("Hey Swift, please don't optimize away \(o)")

                let object = RbObject(ofClass: "String")!
                print("This object is to wipe the stack of refs to 'o's VALUE: \(object)")
            }
        }

        doErrorFree {
            try runGC() // POINT #2

            XCTAssertEqual(initialMTCount, try getMethodsTestHeapCount())
        }
    }

    // Test Ruby stack snooping GC works
    func testStackGc() {
        doErrorFree {
            try Ruby.require(filename: Helpers.fixturePath("methods.rb"))

            try runGC()

            let initialMTCount = try getMethodsTestHeapCount()

            func innerFunction() throws {
                let value = RbObject(ofClass: "MethodsTest")!.withRubyValue { $0 }
                XCTAssertEqual(initialMTCount + 1, try getMethodsTestHeapCount())
                try runGC()
                XCTAssertEqual(initialMTCount + 1, try getMethodsTestHeapCount())
                print("Hey Swift, please don't optimize away \(value)")
            }

            func innerFunction2() {
                let value = RbObject(ofClass: "Array")!.withRubyValue { $0 }
                print("Let's try to wipe out that stack value.... \(value)")
            }

            try innerFunction()
            innerFunction2()

            try runGC()
            XCTAssertEqual(initialMTCount, try getMethodsTestHeapCount())
        }
    }

    static var allTests = [
        ("testSimple", testSimple),
        ("testCopy", testCopy),
        ("testConversions", testConversions),
        ("testInspect", testInspect),
        ("testNewInstance", testNewInstance),
        ("testSymbols", testSymbols),
        ("testHashing", testHashing),
        ("testComparable", testComparable),
        ("testAssociatedObjects", testAssociatedObjects),
        ("testOptionalConformance", testOptionalConformance),
        ("testObjectGc", testObjectGc),
        ("testStackGc", testStackGc)
    ]
}
