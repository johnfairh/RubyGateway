//
//  TestObjMethods.swift
//  RubyGatewayTests
//
//  Distributed under the MIT license, see LICENSE
//

import XCTest
import RubyGateway

// This is about adding methods to objects.
// TestMethods has the method-call/arg stuff and global functions.

class TestObjMethods: XCTestCase {

    // Basic function
    func testSimple() {
        doErrorFree {
            try Ruby.require(filename: Helpers.fixturePath("swift_obj_methods.rb"))


            var callCount = 0

            let clazz = try Ruby.get("EmptyClass")

            let argsSpec = RbMethodArgsSpec(leadingMandatoryCount: 1)
            try clazz.defineMethod(name: "double", argsSpec: argsSpec) { _, method in
                callCount += 1
                let value = Int(method.args.mandatory[0])!
                return RbObject(value * 2)
            }

            // Call from Swift
            guard let instance = RbObject(ofClass: "EmptyClass") else {
                XCTFail("Couldn't create EmptyClass")
                return
            }
            let result = try instance.call("double", args: [1])
            XCTAssertEqual(2, result)
            XCTAssertEqual(1, callCount)

            // Call from Ruby
            let _ = try Ruby.eval(ruby: "test_simple")
            XCTAssertEqual(2, callCount)
        }
    }

    // Check basic error checking
    func testInterfaceErrors() {
        doErrorFree {
            let clazz = try Ruby.get("Object")

            // bad name checked
            doError {
                try clazz.defineMethod(name: "BadNameForAMethod") { _, _ in .nilObject }
            }

            // define method on non-class thing
            let notAClass = RbObject("Not a class")
            doError {
                try notAClass.defineMethod(name: "myMethod") { _, _ in .nilObject }
            }
        }
    }

    // Check modules work as well as classes
    func testModule() {
        doErrorFree {
            try Ruby.require(filename: Helpers.fixturePath("swift_obj_methods.rb"))

            var called = false

            let module = try Ruby.get("EmptyModule")
            XCTAssertEqual(RbType.T_MODULE, module.rubyType)

            try module.defineMethod(name: "answer") { _, _ in
                called = true
                return RbObject("true")
            }

            let _ = try Ruby.eval(ruby: "test_module")
            XCTAssertTrue(called)
        }
    }

    // Check 'self' is passed through correctly
    func testSelf() {
        doErrorFree {
            try Ruby.require(filename: Helpers.fixturePath("swift_obj_methods.rb"))

            var callCount = 0

            let clazz = try Ruby.get("IdentifiedClass")
            try clazz.defineMethod(name: "doubleId") { rbSelf, method in
                callCount += 1
                let myId = try rbSelf.call("uniqueId")
                return myId * 2
            }

            let _ = try Ruby.eval(ruby: "test_self_access")
            XCTAssertEqual(2, callCount)
        }
    }

    // Define a Swift method in base, check can access from derived
    func testInherited() {
        doErrorFree {
            try Ruby.require(filename: Helpers.fixturePath("swift_obj_methods.rb"))

            var callCount = 0

            let clazz = try Ruby.get("BaseClass")
            try clazz.defineMethod(name: "getValue") { rbSelf, method in
                callCount += 1
                return RbObject(22)
            }

            let _ = try Ruby.eval(ruby: "test_inherited")
            XCTAssertEqual(2, callCount)
        }
    }

    // Override a Ruby method with a Swift one
    func testOverridden() {
        doErrorFree {
            try Ruby.require(filename: Helpers.fixturePath("swift_obj_methods.rb"))

            var callCount = 0

            let clazz = try Ruby.get("OverriddenClass")
            try clazz.defineMethod(name: "getValue") { rbSelf, method in
                callCount += 1
                return RbObject(22)
            }

            let _ = try Ruby.eval(ruby: "test_overridden")
            XCTAssertEqual(1, callCount)
        }
    }

    // Docs example
    func testArraySum() {
        doErrorFree {
            let clazz = try Ruby.get("Array")
            try clazz.defineMethod(name: "sum") { rbSelf, method in
                rbSelf.collection.reduce(0, +)
            }

            let theArray = [1, 2, 3]


            let arr = RbObject(theArray)
            let theSum = try arr.call("sum")
            XCTAssertEqual(theArray.reduce(0, +), Int(theSum))
        }
    }

    static var allTests = [
        ("testSimple", testSimple),
        ("testInterfaceErrors", testInterfaceErrors),
        ("testModule", testModule),
        ("testSelf", testSelf),
        ("testInherited", testInherited),
        ("testOverridden", testOverridden),
        ("testArraySum", testArraySum)
    ]
}
