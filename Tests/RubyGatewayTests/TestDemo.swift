//
//  TestDemo.swift
//  RubyGatewayTests
//
//  Distributed under the MIT license, see LICENSE
//

import XCTest
import RubyGateway

/// Some higher-level demos - fail if gems are missing
class TestDemo: XCTestCase {

    func testRouge() throws {
        doErrorFree {
            try Ruby.require(filename: "rouge")
            // Careful to avoid String methods that are unimplemented on Linux....
            let swiftText = try String(contentsOfFile: URL(fileURLWithPath: #file).path, encoding: .utf8)

            let html = try Ruby.get("Rouge").call("highlight", args: [swiftText, "swift", "html"])

            XCTAssertTrue(String(html)!.contains("<span class=\"p\">}</span>"))
        }
    }

    func testDemo() {
        doErrorFree {
            try Ruby.require(filename: Helpers.fixturePath("demo.rb"))

            // Create a named student
            let student = RbObject(ofClass: "Academy::Student", kwArgs: ["name": "barney"])!
            try XCTAssertEqual("barney", String(student.get("name")))

            // Fix their name!
            try student.setInstanceVar("@name", newValue: "Barney")
            try XCTAssertEqual("Barney", String(student.get("name")))

            // Manually add some reading test results
            let readingSubject = RbSymbol("reading")

            try student.call("add_score", args: [readingSubject, 30])
            try student.call("add_score", args: [readingSubject, 36.5])

            guard let avgReadingScore = try Double(student.call("mean_score_for_subject", args: [readingSubject])) else {
                XCTFail("Couldn't get double result out")
                return
            }
            XCTAssertEqual(33.25, avgReadingScore)

            // Create a year group + put barney in it
            let yearGroup = RbObject(ofClass: "Academy::YearGroup")!
            try yearGroup.call("add_student", args: [student])

            // do test - needs block

            try yearGroup.call("report")
        }
    }
}
