import XCTest
@testable import TMLRubyTests

XCTMain([
    testCase(TestVM.allTests),
    testCase(TestNumerics.allTests),
    testCase(TestStrings.allTests),
    testCase(TestConstants.allTests),
])
