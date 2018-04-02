//
//  TestDictionaries.swift
//  RubyGatewayTests
//
//  Distributed under the MIT license, see LICENSE
//

import XCTest
import RubyGateway

class TestDictionaries: XCTestCase {

    func testRoundTrip() {
        let dict = [1: "One", 2: "Two", 3: "Three"]

        let hashObj = RbObject(dict)
        dict.forEach { ele in
            XCTAssertEqual(ele.value, String(hashObj[ele.key]))
        }

        guard let backDict = Dictionary<Int,String>(hashObj) else {
            XCTFail("Couldn't convert back to Swift")
            return
        }
        XCTAssertEqual(dict, backDict)
    }

    static var allTests = [
        ("testRoundTrip", testRoundTrip)
    ]
}
