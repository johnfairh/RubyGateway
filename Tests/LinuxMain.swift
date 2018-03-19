//
//  LinuxMain.swift
//  RubyBridge
//
//  Distributed under the MIT license, see LICENSE
//

import XCTest
@testable import RubyBridgeTests

XCTMain([
    testCase(TestVM.allTests),
    testCase(TestDemo.allTests),
    testCase(TestRbObject.allTests),
    testCase(TestNumerics.allTests),
    testCase(TestMiscObjTypes.allTests),
    testCase(TestOperators.allTests),
    testCase(TestStrings.allTests),
    testCase(TestConstants.allTests),
    testCase(TestVars.allTests),
    testCase(TestCallable.allTests),
    testCase(TestProcs.allTests),
    testCase(TestErrors.allTests),
    testCase(TestFailable.allTests)
])
