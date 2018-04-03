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

    private func getSymNumHash(method: String = "get_sym_num_hash") -> RbObject {
        do {
            try Ruby.require(filename: Helpers.fixturePath("methods.rb"))

            guard let instance = RbObject(ofClass: "MethodsTest") else {
                XCTFail("Couldn't create instance")
                return .nilObject
            }

            return try instance.call(method)
        } catch {
            XCTFail("Unexpected error: \(error)")
            return .nilObject
        }
    }

    func testSwiftTypeConversion() {
        let hashObj = getSymNumHash()

        guard let _ = Dictionary<String, Int>(hashObj) else {
            XCTFail("Can't convert to right type")
            return
        }

        if let badHash1 = Dictionary<Double, Int>(hashObj) {
            XCTFail("Managed to convert String key to Double: \(badHash1)")
            return
        }

        if let badHash2 = Dictionary<String, Dictionary<String, String>>(hashObj) {
            XCTFail("Managed to convert Int value to Array: \(badHash2)")
            return
        }
    }

    func testDuplicateKey() {
        let hashObj = getSymNumHash(method: "get_ambiguous_hash")

        if let oddHash = Dictionary<Int, String>(hashObj) {
            XCTFail("Managed to convert hash: \(oddHash)")
        }
    }

    func testLiteral() {
        let obj: RbObject = [1: "fish", 2: "bucket", 3: "wife", 4: "goat"]
        XCTAssertEqual([1: "fish", 2: "bucket", 3: "wife", 4: "goat"], Dictionary<Int, String>(obj))
    }

    func testNoConversion() {
        do {
            try Ruby.require(filename: Helpers.fixturePath("nonconvert.rb"))

            guard let notHashable = RbObject(ofClass: "NotHashable"),
                let justToH = RbObject(ofClass: "JustToH"),
                let bothToHAndToHash = RbObject(ofClass: "BothToHAndToHash"),
                let trapToHash = RbObject(ofClass: "TrapToHash") else {
                XCTFail("Couldn't create instance")
                return
            }

            if let unexpected = Dictionary<Int, Int>(notHashable) {
                XCTFail("Unexpected conversion: \(unexpected)")
                return
            }

            XCTAssertEqual([1: 2], Dictionary<Int, Int>(justToH))

            XCTAssertEqual([1: 2], Dictionary<Int, Int>(bothToHAndToHash))

            if let unexpected = Dictionary<Int, Int>(trapToHash) {
                XCTFail("Unexpected conversion: \(unexpected)")
                return
            }

            if let unexpected = Dictionary<Int, Int>(RbObject.nilObject) {
                XCTFail("Unexpected conversion of nil to dict: \(unexpected)")
                return
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    static var allTests = [
        ("testRoundTrip", testRoundTrip),
        ("testSwiftTypeConversion", testSwiftTypeConversion),
        ("testDuplicateKey", testDuplicateKey),
        ("testLiteral", testLiteral),
        ("testNoConversion", testNoConversion)
    ]
}
