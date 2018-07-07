//
//  LinuxMain.swift
//  RubyGateway
//
//  Distributed under the MIT license, see LICENSE
//

import XCTest
@testable import RubyGatewayTests

XCTMain([
    testCase(TestVM.allTests),
    testCase(TestDemo.allTests),
    testCase(TestRbObject.allTests),
    testCase(TestNumerics.allTests),
    testCase(TestOperators.allTests),
    testCase(TestMiscObjTypes.allTests),
    testCase(TestStrings.allTests),
    testCase(TestArrays.allTests),
    testCase(TestDictionaries.allTests),
    testCase(TestSets.allTests),
    testCase(TestRanges.allTests),
    testCase(TestConstants.allTests),
    testCase(TestVars.allTests),
    testCase(TestCallable.allTests),
    testCase(TestProcs.allTests),
    testCase(TestErrors.allTests),
    testCase(TestFailable.allTests),
    testCase(TestThreads.allTests),
    testCase(TestCollection.allTests),
    testCase(TestComplex.allTests),
    testCase(TestRational.allTests),
])
