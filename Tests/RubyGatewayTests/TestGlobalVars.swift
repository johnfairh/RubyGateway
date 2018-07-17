//
//  TestGlobalVars.swift
//  RubyGatewayTests
//
//  Distributed under the MIT license, see LICENSE
//

import XCTest
import RubyGateway

/// Virtual GVars.
class TestGlobalVars: XCTestCase {

    func testVirtual() {
        doErrorFree {
            let initialValue = 22
            let newValue = 108

            var modelValue = initialValue

            let gvarName = "$myVirtualGlobal"

            try Ruby.defineGlobalVar(name: gvarName,
                                     get: { RbObject(modelValue) },
                                     set: { modelValue = Int($0)! })

            let rbCurrent = try Ruby.eval(ruby: gvarName)
            XCTAssertEqual(initialValue, modelValue)
            XCTAssertEqual(modelValue, Int(rbCurrent))

            let _ = try Ruby.eval(ruby: "\(gvarName) = \(newValue)")
            XCTAssertEqual(newValue, modelValue)
        }
    }

    func testReadonly() {
        doErrorFree {
            let gvarName = "$myVirtualGlobal"
            let modelValue = "Fish"

            try Ruby.defineGlobalVar(name: gvarName,
                                     get: { RbObject(modelValue) })

            let rbCurrent = try Ruby.eval(ruby: gvarName)
            XCTAssertEqual(modelValue, String(rbCurrent))

            doError {
                let answer = try Ruby.eval(ruby: "\(gvarName) = 'Bucket'")
                XCTFail("Managed to assign to readonly gvar: \(answer)")
            }
        }
    }

    func testSwiftException() {
        doErrorFree {
            let gvarName = "$myVirtualGlobal"

            try Ruby.defineGlobalVar(name: gvarName,
                                     get: { RbObject(22) },
                                     set: { _ in throw RbException(message: "Bad new value!") })

            doError {
                let answer = try Ruby.eval(ruby: "\(gvarName) = 44")
                XCTFail("Managed to set unsettable: \(answer)")
            }
        }
    }

    static var allTests = [
        ("testVirtual", testVirtual),
        ("testReadonly", testReadonly),
        ("testSwiftException", testSwiftException)
    ]
}
