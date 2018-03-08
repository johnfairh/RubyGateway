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

    func testDemo() {
        do {
            try Ruby.require(filename: Helpers.fixturePath("demo.rb"))

            // Create a named student
            let student = RbObject(ofClass: "Academy::Student", kwArgs: [("name", "barney")])!
            try XCTAssertEqual("barney", String(student.get("name")))

            // Fix their name!
            try student.setInstanceVar("@name", newValue: "Barney")
            try XCTAssertEqual("Barney", String(student.get("name")))

            // Manually add some reading test results
            let readingSubject = RbObject(symbolName: "reading")

            try student.call("add_score", args: [readingSubject, 30])
            try student.call("add_score", args: [readingSubject, 36.5])

            let avgReadingScore = try student.call("mean_score_for_subject", args: [readingSubject])
            XCTAssertEqual(33.25, Double(avgReadingScore))

            // Create a year group + put barney in it
            let yearGroup = RbObject(ofClass: "Academy::YearGroup")!
            try yearGroup.call("add_student", args: [student])

            // do test - needs block

            try yearGroup.call("report")

        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    static var allTests = [
        ("testRouge", testRouge),
        ("testWikipedia", testWikipedia)
    ]
}
