//
//  TestSets.swift
//  RubyGatewayTests
//
//  Distributed under the MIT license, see LICENSE
//

import XCTest
import RubyGateway

class TestSets: XCTestCase {
    func testRoundTrip() {
        let aSet: Set<Int> = [1, 2, 3, 4]
        let rbSet = RbObject(aSet)
        guard let backSet = Set<Int>(rbSet) else {
            XCTFail("Couldn't convert set back - \(rbSet)")
            return
        }
        XCTAssertEqual(aSet, backSet)
    }

    private func getSet(method: String) -> RbObject {
        return doErrorFree(fallback: .nilObject) {
            try Ruby.require(filename: Helpers.fixturePath("methods.rb"))

            return try Ruby.get("MethodsTest").get(method)
        }
    }

    func testElementConversion() {
        let setObj = getSet(method: "get_str_set")

        guard let _ = Set<String>(setObj) else {
            XCTFail("Couldn't convert Ruby set \(setObj)")
            return
        }

        if let dSet = Set<Double>(setObj) {
            XCTFail("Managed to convert string set to FP: \(dSet)")
            return
        }
    }

    func testAmbiguousElements() {
        let setObj = getSet(method: "get_ambiguous_num_set")

        if let iSet = Set<Int>(setObj) {
            XCTFail("Managed to convert odd set to Swift: \(iSet)")
            return
        }
    }

    func testAmbiguousRubyConversion() {
        let arr = [Helpers.ImpreciseRuby(1), Helpers.ImpreciseRuby(2)]
        let set = Set(arr)
        XCTAssertEqual(arr.count, set.count)

        let rubyArr = RbObject(arr)
        XCTAssertFalse(rubyArr.isNil)

        let rubySet = RbObject(set)
        XCTAssertTrue(rubySet.isNil)
    }
}
