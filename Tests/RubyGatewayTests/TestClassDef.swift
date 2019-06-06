//
//  TestClassDef.swift
//  RubyGatewayTests
//
//  Distributed under the MIT license, see LICENSE
//

import XCTest
import RubyGateway

class TestClassDef: XCTestCase {

    // Basic function
    func testSimple() {
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
        }
    }

    static var allTests = [
        ("testSimple", testSimple),
    ]
}
