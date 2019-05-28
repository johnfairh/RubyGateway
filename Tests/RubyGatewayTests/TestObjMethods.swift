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

    func testSimple() {
        doErrorFree {
            try Ruby.require(filename: Helpers.fixturePath("swift_obj_methods.rb"))

            let clazz = try Ruby.get("EmptyClass")

            let argsSpec = RbMethodArgsSpec(leadingMandatoryCount: 1)
            try clazz.defineMethod(name: "double", argsSpec: argsSpec) { _, method in
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

            // Call from Ruby
            let _ = try Ruby.eval(ruby: "test_simple")
        }
    }

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

    func testModule() {
        doErrorFree {
            try Ruby.require(filename: Helpers.fixturePath("swift_obj_methods.rb"))

            let module = try Ruby.get("EmptyModule")
            XCTAssertEqual(RbType.T_MODULE, module.rubyType)

            try module.defineMethod(name: "answer") { _, _ in
                RbObject("true")
            }

            let _ = try Ruby.eval(ruby: "test_module")
        }
    }

    static var allTests = [
        ("testSimple", testSimple),
        ("testInterfaceErrors", testInterfaceErrors),
        ("testModule", testModule)
    ]
}
