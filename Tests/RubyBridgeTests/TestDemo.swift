//
//  TestDemo.swift
//  RubyBridgeTests
//
//  Distributed under the MIT license, see LICENSE
//

import XCTest
import CRuby
import RubyBridge

/// Some higher-level demos - skipped if gems are missing
class TestDemo: XCTestCase {

    func testRouge() {
        guard let _ = try? Ruby.require(filename: "rouge") else {
            return
        }

        do {
            // Careful to avoid String methods that are unimplemented on Linux....
            let swiftText = try String(contentsOfFile: URL(fileURLWithPath: #file).path, encoding: .utf8)

            let html = try Ruby.get("Rouge").call("highlight", args: [swiftText, "swift", "html"])

            XCTAssertTrue(String(html)!.contains("<span class=\"p\">}</span>"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testWikipedia() {
        guard let _ = try? Ruby.require(filename: "wikipedia") else {
            return
        }

        do {
            let page = try Ruby.get("Wikipedia").call("find", args: ["Swift"])

            try XCTAssertEqual("Swift", String(page.get("title")))

            try XCTAssertTrue(String(page.get("summary"))!.contains("Apodidae"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    static var allTests = [
        ("testRouge", testRouge),
        ("testWikipedia", testWikipedia)
    ]
}
