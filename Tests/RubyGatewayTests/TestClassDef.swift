//
//  TestClassDef.swift
//  RubyGatewayTests
//
//  Distributed under the MIT license, see LICENSE
//

import XCTest
import RubyGateway

class TestClassDef: XCTestCase {

    // Simple class
    func testSimpleClass() {
        doErrorFree {
            let className = "MyClass"
            let myClass = try Ruby.defineClass(name: className)
            XCTAssertEqual(className, String(myClass))
            XCTAssertEqual([className, "Object", "Kernel", "BasicObject"], Array<String>(try myClass.call("ancestors")))

            guard let myInstance = RbObject(ofClass: className) else {
                XCTFail("Can't create instance")
                return
            }
            XCTAssertEqual(className, String(myInstance.class!))

            let myClass2 = try Ruby.get(className)
            XCTAssertEqual(RbType.T_CLASS, myClass2.rubyType)
            XCTAssertEqual(myClass, myClass2)
        }
    }

    // Error check
    func testBadClassDef() {
        let notAclass = RbObject(5)
        let className = "MyClass"
        doError {
            let myClass = try Ruby.defineClass(name: className, parent: notAclass)
            XCTFail("Managed to inherit from an instance: \(myClass)")
        }
    }

    // Simple module
    func testSimpleModule() {
        doErrorFree {
            let modName = "MyModule"
            let myMod = try Ruby.defineModule(name: modName)
            XCTAssertEqual(modName, String(myMod))
            XCTAssertEqual("Module", String(myMod.class!))

            let myMod2 = try Ruby.get(modName)
            XCTAssertEqual(myMod2.rubyType, RbType.T_MODULE)
            XCTAssertEqual(myMod, myMod2)
        }
    }

    // Nested and Ruby access
    func testNestedDefs() {
        doErrorFree {
            try Ruby.require(filename: Helpers.fixturePath("swift_classes.rb"))

            try Ruby.defineModule(name: "MyOuterModule")
            try Ruby.defineModule(name: "MyOuterModule::MyInnerModule")

            let parentClass = try Ruby.get("MyParentClass")
            let myClass = try Ruby.defineClass(name: "MyOuterModule::MyInnerModule::MyClass", parent: parentClass)
            var called = false
            try myClass.defineMethod(name: "value") { _, _ in
                called = true
                return RbObject(100)
            }

            let _ = try Ruby.eval(ruby: "test_swiftclass")
            XCTAssertTrue(called)
        }
    }

    static var allTests = [
        ("testSimpleClass", testSimpleClass),
        ("testBadClassDef", testBadClassDef),
        ("testSimpleModule", testSimpleModule),
        ("testNestedDefs", testNestedDefs),
    ]
}
