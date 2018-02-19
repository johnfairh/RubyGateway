import XCTest
@testable import RubyBridgeTests

XCTMain([
    testCase(TestVM.allTests),
    testCase(TestNumerics.allTests),
    testCase(TestStrings.allTests),
    testCase(TestConstants.allTests),
    testCase(TestRbObject.allTests),
])
