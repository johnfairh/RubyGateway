//
//  TestArrays.swift
//  RubyGatewayTests
//
//  Distributed under the MIT license, see LICENSE
//

import XCTest
import RubyGateway

class TestArrays: XCTestCase {

    // Kudos to Swift to be able to write this genericly...
    private func doTestRoundTrip<T>(arr: [T]) where T: RbObjectConvertible, T: Equatable {
        let arrObj = RbObject(arr)
        for (offset, elt) in arr.enumerated() {
            XCTAssertEqual(elt, T(arrObj[offset]))
        }
        guard let arrBack = Array<T>(arrObj) else {
            XCTFail("Couldn't get back to Swift array")
            return
        }
        XCTAssertEqual(arr, arrBack)
    }

    /// One primitive...
    func testRoundTripInt() {
        doTestRoundTrip(arr: [1, 2, 3])
    }

    /// Another primitive...
    func testRoundTripString() {
        doTestRoundTrip(arr: ["one", "two", "three"])
    }

    /// Arrays of arrays.  Can't mix types using this kind of interface.
    func testRoundTripNested() {
        doTestRoundTrip(arr: [ ["a", "b", "c"], ["x", "y"], ["q"] ])
    }

    /// Ruby understands our arrays + vice versa
    func testRubyInterop() {
        do {
            try Ruby.require(filename: Helpers.fixturePath("methods.rb"))

            guard let instance = RbObject(ofClass: "MethodsTest") else {
                XCTFail("Couldn't create instance")
                return
            }

            // Get Ruby array + convert to Swift

            let arrObj = try instance.call("get_num_array")
            guard let array = Array<Int>(arrObj) else {
                XCTFail("Couldn't convert to Swift array")
                return
            }
            XCTAssertEqual([1, 2, 3], array)

            // Pass Swift array to Ruby
            let sumObj = try instance.call("sum_array", args: [[1, 2, 3]])
            XCTAssertEqual(1 + 2 + 3, Int(sumObj))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    /// Heterogeneous arrays (+ to_a behavior of Array)
    func testMixedArrays() {
        do {
            try Ruby.require(filename: Helpers.fixturePath("methods.rb"))

            guard let instance = RbObject(ofClass: "MethodsTest") else {
                XCTFail("Couldn't create instance")
                return
            }

            if let intArray = Array<Int>(instance) {
                XCTFail("Managed to convert array to ints: \(intArray)")
                return
            }

            guard let objArray = Array<RbObject>(instance) else {
                XCTFail("Couldn't convert to obj array")
                return
            }

            XCTAssertEqual(1, Int(objArray[0]))
            XCTAssertEqual("two", String(objArray[1]))
            XCTAssertEqual(3.0, Double(objArray[2]))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    /// Array literal
    func testArrayLiteral() {
        let obj: RbObject = [1, 2, 3]
        XCTAssertEqual([1, 2, 3], Array<Int>(obj))
    }

    /// Nonconvertible (tricky!)
    func testNoArrayConversion() {
        do {
            try Ruby.require(filename: Helpers.fixturePath("nonconvert.rb"))

            guard let instance = RbObject(ofClass: "NotArrayable") else {
                XCTFail("Couldn't create instance")
                return
            }

            if let arr = Array<RbObject>(instance) {
                XCTFail("Managed to arrayify unarrayifyable: \(arr)")
                return
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    static var allTests = [
        ("testRoundTripInt", testRoundTripInt),
        ("testRoundTripString", testRoundTripString),
        ("testRoundTripNested", testRoundTripNested),
        ("testRubyInterop", testRubyInterop),
        ("testMixedArrays", testMixedArrays)
    ]
}
