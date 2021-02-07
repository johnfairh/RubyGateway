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

    // read/write, native Swift type
    func testVirtualNative() {
        doErrorFree {
            let initialValue = 22
            let newValue = 108

            var modelValue = initialValue

            let gvarName = "$myVirtualGlobal"

            try Ruby.defineGlobalVar(gvarName,
                                     get: { modelValue },
                                     set: { modelValue = $0 })

            let rbCurrent = try Ruby.eval(ruby: gvarName)
            XCTAssertEqual(initialValue, modelValue)
            XCTAssertEqual(modelValue, Int(rbCurrent))

            let _ = try Ruby.eval(ruby: "\(gvarName) = \(newValue)")
            XCTAssertEqual(newValue, modelValue)

            // Assign a nonconvertible type, system picks it up
            doError {
                let _ = try Ruby.eval(ruby: "\(gvarName) = 'fishcakes'")
            }
            XCTAssertEqual(newValue, modelValue)
        }
    }

    // read/write, RbObject
    func testVirtualObj() {
        doErrorFree {
            let initialIntValue = 100
            let targetStringValue = "Berry"

            var wrappedObj = RbObject(initialIntValue)
            let gvarName = "$myGlobal"

            try Ruby.defineGlobalVar(gvarName,
                                     get: { wrappedObj },
                                     set: { wrappedObj = $0 })

            let rbCurrent = try Ruby.eval(ruby: gvarName)
            XCTAssertEqual(initialIntValue, Int(rbCurrent))

            let _ = try Ruby.eval(ruby: "\(gvarName) = '\(targetStringValue)'")
            XCTAssertEqual(targetStringValue, String(wrappedObj))
        }
    }

    func testReadonly() {
        doErrorFree {
            let gvarName = "$myVirtualGlobal"
            let modelValue = "Fish"

            try Ruby.defineGlobalVar(gvarName) { modelValue }

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

            try Ruby.defineGlobalVar(gvarName,
                                     get: { 22 },
                                     set: { _ in throw RbException(message: "Bad new value!") })

            doError {
                let answer = try Ruby.eval(ruby: "\(gvarName) = 44")
                XCTFail("Managed to set unsettable: \(answer)")
            }
        }
    }
}
