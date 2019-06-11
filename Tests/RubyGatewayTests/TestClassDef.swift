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
            let myClass = try Ruby.defineClass(className)
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
            let myClass = try Ruby.defineClass(className, parent: notAclass)
            XCTFail("Managed to inherit from an instance: \(myClass)")
        }

        doError {
            let myClass = try Ruby.defineClass(className, under: notAclass)
            XCTFail("Managed to nest under an instance: \(myClass)")
        }

        doError {
            let myMod = try Ruby.defineModule(className, under: notAclass)
            XCTFail("Managed to nest a module under an instance: \(myMod)")
        }

        let objClass = try! Ruby.get("Object")
        doError {
            let myClass = try Ruby.defineClass("::", under: objClass)
            XCTFail("Managed to define class with odd name \(myClass)")
        }

        doError {
            try objClass.include(module: notAclass)
            XCTFail("Managed to include an instance into a class")
        }
    }

    // Simple module
    func testSimpleModule() {
        doErrorFree {
            let modName = "MyModule"
            let myMod = try Ruby.defineModule(modName)
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

            let outerMod = try Ruby.defineModule("MyOuterModule")
            let innerMod = try Ruby.defineModule("MyInnerModule", under: outerMod)

            let parentClass = try Ruby.get("MyParentClass")
            let myClass = try Ruby.defineClass("MyClass", parent: parentClass, under: innerMod)
            var called = false
            try myClass.defineMethod("value") { _, _ in
                called = true
                return RbObject(100)
            }

            let _ = try Ruby.eval(ruby: "test_swiftclass")
            XCTAssertTrue(called)
        }
    }

    // Module injection
    func testModuleInjection() {
        doErrorFree {
            try Ruby.require(filename: Helpers.fixturePath("swift_classes.rb"))

            let mod = try Ruby.get("InjectableModule")
            let c1 = try Ruby.get("InjecteeClass1")
            let c2 = try Ruby.get("InjecteeClass2")

            try c1.include(module: mod)
            try c2.prepend(module: mod)

            try Ruby.eval(ruby: "test_inject1")

            try c1.extend(module: mod)
            try Ruby.eval(ruby: "test_inject2")
        }
    }

    private func runGC() throws {
        try Ruby.get("GC").call("start")
    }

    // Bound Swift class
    func testBoundSwiftClass() {

        class MyBoundClass {
            static var initCount = 0
            static var deinitCount = 0

            init() {
                MyBoundClass.initCount += 1
            }

            deinit {
                MyBoundClass.deinitCount += 1
            }
        }

        doErrorFree {
            let boundClass = try Ruby.defineClass("SwiftBound", maker: MyBoundClass.init)

            XCTAssertEqual(0, MyBoundClass.initCount)
            XCTAssertEqual(0, MyBoundClass.deinitCount)

            func localFunc() {
                guard let inst = RbObject(ofClass: "SwiftBound") else {
                    XCTFail("Can't create instance")
                    return
                }

                withExtendedLifetime(inst) {
                    XCTAssertEqual(1, MyBoundClass.initCount)
                    XCTAssertEqual(0, MyBoundClass.deinitCount)
                }
            }

            localFunc()

            try runGC()
            
            XCTAssertEqual(1, MyBoundClass.deinitCount)
        }
    }



    static var allTests = [
        ("testSimpleClass", testSimpleClass),
        ("testBadClassDef", testBadClassDef),
        ("testSimpleModule", testSimpleModule),
        ("testNestedDefs", testNestedDefs),
        ("testModuleInjection", testModuleInjection),
        ("testBoundSwiftClass", testBoundSwiftClass)
    ]
}
