//
//  TestClassDef.swift
//  RubyGatewayTests
//
//  Distributed under the MIT license, see LICENSE
//

import XCTest
@testable /* RbObjectBinding */ import RubyGateway
import RubyGatewayHelpers

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
            XCTAssertEqual(className, String(try myInstance.call("class")))

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
            XCTAssertEqual("Module", String(try myMod.call("class")))

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
            nonisolated(unsafe) var called = false
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

    // Bound Swift classes

    class MyBoundClass: @unchecked Sendable {

        static nonisolated(unsafe) var initCount = 0
        static nonisolated(unsafe) var deinitCount = 0
        static nonisolated(unsafe) var generation = 0

        static func resetCounts() {
            print("resetCounts")
            initCount = 0
            deinitCount = 0
        }

        static let fingerprintValue = "FINGERPRINT"

        var fingerprint = MyBoundClass.fingerprintValue

        func getFingerprint(method: RbMethod) throws -> RbObject {
            RbObject(fingerprint)
        }

        var generation: Int

        init() {
            generation = MyBoundClass.generation
            MyBoundClass.initCount += 1
            print("init, initCount=\(MyBoundClass.initCount) deinitCount=\(MyBoundClass.deinitCount)")
        }
        
        deinit {
            if generation == MyBoundClass.generation {
                MyBoundClass.deinitCount += 1
                print("deinit, initCount=\(MyBoundClass.initCount) deinitCount=\(MyBoundClass.deinitCount)")
            } else {
                print("Drop deinit, wrong generation")
            }
        }
    }

    // Basic create/delete matching
    func testBoundSwiftClass() {
        doErrorFree {
            try runGC()
            MyBoundClass.generation += 1
            MyBoundClass.resetCounts()
        }

        doErrorFree {
            try runGC()

            try Ruby.defineClass("SwiftBound", initializer: MyBoundClass.init)

            XCTAssertEqual(0, MyBoundClass.initCount)
            XCTAssertEqual(0, MyBoundClass.deinitCount)

            do {
                guard let inst = RbObject(ofClass: "SwiftBound") else {
                    XCTFail("Can't create instance")
                    return
                }

                XCTAssertEqual(1, MyBoundClass.initCount)
                XCTAssertEqual(0, MyBoundClass.deinitCount)

                let obj = try inst.getBoundObject(type: MyBoundClass.self)
                XCTAssertEqual(MyBoundClass.fingerprintValue, obj.fingerprint)

                guard let dummy = RbObject(ofClass: "String") else {
                    XCTFail("Can't create string!")
                    return
                }
                print("The point of dummy is to overwrite any SwiftBound VALUE on the stack: \(dummy)")
            }
        }

        doErrorFree {
            try runGC()

            XCTAssertEqual(1, MyBoundClass.deinitCount)
        }
    }

    // Nesting name resolution works properly
    func testNestedBound() {
        doErrorFree {
            let module = try Ruby.defineModule("RbTests")
            let _ = try Ruby.defineClass("BoundNested", under: module) {
                MyBoundClass()
            }

            guard let _ = RbObject(ofClass: "RbTests::BoundNested") else {
                XCTFail("Can't create instance")
                return
            }
        }
    }

    // Internal special cases
    func testSpecialCases() {
        doErrorFree {
            do {
                let instance = RbClassBinding.alloc(name: "NotABoundClass")
                XCTAssertNil(instance)
            }

            do {
                let obj = RbObject(22)
                let opaque = obj.withRubyValue { rbg_get_bound_object($0) }
                XCTAssertNil(opaque)

                doError {
                    let val = try obj.getBoundObject(type: AnyObject.self)
                    XCTFail("Managed to get bound object from an int: \(val)")
                }
            }

            do {
                let clazz = try Ruby.defineClass("NotABoundClassEither")
                doError {
                    try clazz.defineMethod("method", method: MyBoundClass.getFingerprint)
                    XCTFail("Managed to bind a Swift method to an unbound class")
                }
            }
        }
    }

    // Bound methods
    func testBoundMethods() {
        doErrorFree {
            MyBoundClass.generation += 1
            let myClass = try Ruby.defineClass("PeerMethods", initializer: MyBoundClass.init)
            try myClass.defineMethod("fingerprint", method: MyBoundClass.getFingerprint)

            guard let instance = RbObject(ofClass: "PeerMethods") else {
                XCTFail("Can't create instance")
                return
            }
            let fingerprint = try instance.call("fingerprint")
            XCTAssertEqual(MyBoundClass.fingerprintValue, String(fingerprint))

            try Ruby.require(filename: Helpers.fixturePath("swift_classes.rb"))

            try _ = Ruby.eval(ruby: "test_bound1")
        }
    }

    class InvaderModel: @unchecked Sendable {
        private var name = ""

        init() {
        }

        func initialize(rbMethod: RbMethod) throws {
            name = try rbMethod.args.mandatory[0].convert()
        }

        func name(rbMethod: RbMethod) throws -> String {
            return name
        }

        func listStats(rbMethod: RbMethod) throws -> RbObject {
            if rbMethod.isBlockGiven {
                try rbMethod.yieldBlock(args: ["Health", 100])
                try rbMethod.yieldBlock(args: ["Shield", 25])
                return .nilObject
            } else {
                return ["Health", 100, "Shield", 25]
            }
        }

        func fire(rbMethod: RbMethod) throws {
            // bang
        }
    }

    func testDemoCode() {
        doErrorFree {
            let invaderClass = try Ruby.defineClass("Invader", initializer: InvaderModel.init)
            try invaderClass.defineMethod("initialize", argsSpec: .basic(1), method: InvaderModel.initialize)
            try invaderClass.defineMethod("name", method: InvaderModel.name)
            try invaderClass.defineMethod("list_stats", method: InvaderModel.listStats)
            try invaderClass.defineMethod("fire", method: InvaderModel.fire)

            try Ruby.require(filename: Helpers.fixturePath("swift_classes.rb"))

            let res = try Ruby.eval(ruby: "test_invader")
            XCTAssertEqual(true, res)
        }
    }
}
