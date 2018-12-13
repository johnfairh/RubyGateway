//
//  TestMethods.swift
//  RubyGatewayTests
//
//  Distributed under the MIT license, see LICENSE
//

import Foundation
import XCTest
@testable /* RbMethod internals */ import RubyGateway

extension RbMethodArgsSpec {
    func check(args: RbMethodArgs) {
        XCTAssertEqual(totalMandatoryCount, args.mandatory.count)
        XCTAssertEqual(optionalCount, args.optional.count)
        if !supportsSplat {
            XCTAssertEqual(0, args.splatted.count)
        }
        let expectedKeywords = mandatoryKeywords.union(optionalKeywordValues.keys).sorted()
        let actualKeywords = args.keyword.keys.sorted()
        XCTAssertEqual(expectedKeywords, actualKeywords)
    }
}

extension RbMethod {
    func checkArgs() {
        argsSpec.check(args: args)
    }
}

/// Swift methods
class TestMethods: XCTestCase {

    // basic data round-trip
    func testFixedArgsRoundTrip() {
        doErrorFree {
            let funcName = "myGlobal"
            let argCount = 1
            let argValue = "Fish"
            let retValue = 8.9
            var visited = false

            try Ruby.defineGlobalFunction(name: funcName, argsSpec: RbMethodArgsSpec(leadingMandatoryCount: argCount)) { _, method in
                method.checkArgs()
                XCTAssertFalse(visited)
                visited = true
                XCTAssertEqual(argCount, method.args.mandatory.count)
                XCTAssertEqual(argValue, String(method.args.mandatory[0]))
                return RbObject(retValue)
            }

            let actualRetValue = try Ruby.call(funcName, args: [argValue])

            XCTAssertTrue(visited)
            XCTAssertEqual(retValue, Double(actualRetValue))
        }
    }

    func testVarArgsRoundTrip() {
        doErrorFree {
            let funcName = "myGlobal"
            let retValue = 8.9
            var visited = false

            try Ruby.defineGlobalFunction(name: funcName) { _, method in
                method.checkArgs()
                XCTAssertFalse(visited)
                visited = true
                XCTAssertEqual(method.args.mandatory.count, 0)
                XCTAssertEqual(method.args.splatted.count, 0)
                return RbObject(retValue)
            }

            let actualRetValue = try Ruby.call(funcName)

            XCTAssertTrue(visited)
            XCTAssertEqual(retValue, Double(actualRetValue))
        }
    }

    // Argc runtime mismatch
    func testArgcMismatch() {
        doErrorFree {
            let funcName = "myGlobal"
            let expectedArgCount = 1

            try Ruby.defineGlobalFunction(name: funcName, argsSpec: RbMethodArgsSpec(leadingMandatoryCount: expectedArgCount)) { _, _ in
                XCTFail("Accidentally called function requiring an arg without any")
                return .nilObject
            }

            doError {
                let _ = try Ruby.call(funcName)
            }
        }
    }

    // Goodpath calling Swift + Ruby block from a function
    func testGoodBlock() {
        doErrorFree {
            let funcName = "myGlobal"
            var funcCalled = false
            var blockCalled = false
            let expectedBlockResult = 4.0
            let expectedFuncResult = "alldone"

            try Ruby.defineGlobalFunction(name: funcName, argsSpec: RbMethodArgsSpec(requiresBlock: true)) { _, method in
                XCTAssertTrue(method.isBlockGiven)
                XCTAssertFalse(funcCalled)
                let blockResult = try method.yieldBlock()
                XCTAssertEqual(expectedBlockResult, Double(blockResult))
                funcCalled = true
                return RbObject(expectedFuncResult)
            }

            let funcResult = try Ruby.call(funcName) { blockArgs in
                XCTAssertFalse(blockCalled)
                blockCalled = true
                XCTAssertEqual(0, blockArgs.count)
                return RbObject(expectedBlockResult)
            }

            XCTAssertTrue(funcCalled)
            XCTAssertTrue(blockCalled)
            XCTAssertEqual(expectedFuncResult, String(funcResult))

            // Do the ruby version too!
            funcCalled = false
            let _ = try Ruby.eval(ruby: "\(funcName) { next 4.0 }")
            XCTAssertTrue(funcCalled)
        }
    }

    // Missing block
    func testErrorNoBlock() {
        doErrorFree {
            let funcName = "myGlobal"
            var funcCalled = false

            try Ruby.defineGlobalFunction(name: funcName) { _, method in
                funcCalled = true
                try method.needsBlock()
                return .nilObject
            }

            doError {
                let _ = try Ruby.call(funcName)
            }
            XCTAssertTrue(funcCalled)
        }
    }

    // Manual block invocation
    func testManualBlock() {
        doErrorFree {
            let funcName = "myGlobal"
            var funcCalled = false
            var blockCalled = false

            try Ruby.defineGlobalFunction(name: funcName) { _, method in
                let block = try method.captureBlock()
                try block.call("call")
                funcCalled = true
                return .nilObject
            }

            try Ruby.call(funcName) { blockArgs in
                blockCalled = true
                XCTAssertEqual(0, blockArgs.count)
                return .nilObject
            }

            XCTAssertTrue(funcCalled)
            XCTAssertTrue(blockCalled)
        }
    }

    // Block with args
    func testBlockArgs() {
        doErrorFree {
            let funcName = "myGlobal"
            var funcCalled = false
            var blockCalled = false
            let expectedBlockArg = 4.0

            try Ruby.defineGlobalFunction(name: funcName, argsSpec: RbMethodArgsSpec(requiresBlock: true)) { _, method in
                XCTAssertTrue(method.isBlockGiven)
                try method.needsBlock()
                XCTAssertFalse(funcCalled)
                let _ = try method.yieldBlock(args: [expectedBlockArg])
                funcCalled = true
                return .nilObject
            }

            let _ = try Ruby.call(funcName) { blockArgs in
                XCTAssertFalse(blockCalled)
                blockCalled = true
                XCTAssertEqual(1, blockArgs.count)
                XCTAssertEqual(expectedBlockArg, Double(blockArgs[0]))
                return .nilObject
            }

            XCTAssertTrue(funcCalled)
            XCTAssertTrue(blockCalled)
        }
    }

    // break / return / next from block
    func testBlockBreakReturn() {
        doErrorFree {
            try Ruby.require(filename: Helpers.fixturePath("swift_methods.rb"))

            try Ruby.defineGlobalFunction(name: "swift_calls_block") { _, method in
                try method.needsBlock()
                let _ = try method.yieldBlock()
                return RbObject(100)
            }

            try Ruby.defineGlobalFunction(name: "swift_returns_block") { _, method in
                try method.needsBlock()
                return try method.yieldBlock()
            }

            let testSuffixes = [100, 42, 200, 44, 22, 24, 4]
            try testSuffixes.forEach { val in
                let funcName = "ruby_should_return_\(val)"
                let result = try Ruby.call(funcName)
                XCTAssertEqual(val, Int(result))
            }
        }
    }

    // Mandatory arg counting
    func testMandatoryArgCount() {
        doErrorFree {
            let argSpecs = [0, 1, 4].map { RbMethodArgsSpec(leadingMandatoryCount: $0) }

            try argSpecs.forEach { spec in
                let fname = "myfunc"
                try Ruby.defineGlobalFunction(name: fname, argsSpec: spec) { _, method in
                    method.checkArgs()
                    return .nilObject
                }

                func callIt(argc: Int) throws {
                    let argv = Array(repeating: RbObject.nilObject, count: argc)
                    let rc = try Ruby.call(fname, args: argv)
                    XCTAssertEqual(rc, .nilObject)
                }

                if spec.totalMandatoryCount > 0 {
                    doError { try callIt(argc: 0) }
                    doError { try callIt(argc: spec.totalMandatoryCount - 1) }
                }
                try callIt(argc: spec.totalMandatoryCount)
                doError { try callIt(argc: spec.totalMandatoryCount + 1) }
            }
        }
    }

    // Optional args
    func testOptionalArgs() {
        doErrorFree {
            // def f(a=3, b=4)
            let spec_f = RbMethodArgsSpec(optionalValues: [3, 4])
            let func_f = "f"
            var expectedArgs_f: [RbObject] = []
            try Ruby.defineGlobalFunction(name: func_f, argsSpec: spec_f) { _, method in
                method.checkArgs()
                XCTAssertEqual(expectedArgs_f, method.args.optional)
                return .nilObject
            }

            let passedArgs = [ [],
                               [RbObject(5)],
                               [RbObject("A"), RbObject(1.3)] ]
            let expectedArgs = [ [RbObject(3), RbObject(4)],
                                 [RbObject(5), RbObject(4)],
                                 [RbObject("A"), RbObject(1.3)] ]

            try zip(passedArgs, expectedArgs).forEach { passed, expected in
                expectedArgs_f = expected
                try Ruby.call(func_f, args: passed)
            }
        }
    }

    // Splat args
    func testSplatArgs() {
        doErrorFree {
            // def f(*a)
            let spec_f = RbMethodArgsSpec(supportsSplat: true)
            let func_f = "f"
            var expectedArgs_f: [RbObject] = []
            try Ruby.defineGlobalFunction(name: func_f, argsSpec: spec_f) { _, method in
                method.checkArgs()
                XCTAssertEqual(expectedArgs_f, method.args.splatted)
                return .nilObject
            }

            let passedArgs = [ [],
                               [RbObject(5)],
                               [RbObject("A"), RbObject(1.3)] ]

            try passedArgs.forEach { args in
                expectedArgs_f = args
                try Ruby.call(func_f, args: args)
            }
        }
    }

    // Splat plus mandatory unusual error case
    func testSplatMandatoryArgError() {
        doErrorFree {
            // def f(a, *b, c)
            let spec_f = RbMethodArgsSpec(leadingMandatoryCount: 1,
                                          supportsSplat: true,
                                          trailingMandatoryCount: 1)
            let func_f = "f"
            var a_val: RbObject = .nilObject
            var c_val: RbObject = .nilObject
            var b_count: Int = 0
            try Ruby.defineGlobalFunction(name: func_f, argsSpec: spec_f) { _, method in
                method.checkArgs()
                XCTAssertEqual(a_val, method.args.mandatory[0])
                XCTAssertEqual(b_count, method.args.splatted.count)
                XCTAssertEqual(c_val, method.args.mandatory[1])
                return .nilObject
            }

            doError { try Ruby.call(func_f) }
            doError { try Ruby.call(func_f, args: [1]) }
            do {
                a_val = 1
                b_count = 0
                c_val = "fish"
                try Ruby.call(func_f, args: [a_val, c_val])
            }
            do {
                a_val = 4
                b_count = 2
                c_val = 1.4
                try Ruby.call(func_f, args: [a_val, 4, 8, c_val])
            }
        }
    }

    // Mix-up all pos arg types
    func testAllPositionalArgTypes() {
        doErrorFree {
            // def f(a, b, c=8, *d, e, f)
            let spec_f = RbMethodArgsSpec(leadingMandatoryCount: 2,
                                          optionalValues: [8],
                                          supportsSplat: true,
                                          trailingMandatoryCount: 2)
            let func_f = "f"
            let expectedM1 = [RbObject(5), RbObject(2)]
            let expectedM2 = [RbObject(1.3), RbObject("fish")]
            let expectedOptional = [RbObject(12)]
            let expectedSplatted = [RbObject("bucket")]
            try Ruby.defineGlobalFunction(name: func_f, argsSpec: spec_f) { _, method in
                method.checkArgs()
                XCTAssertEqual(expectedM1 + expectedM2, method.args.mandatory)
                XCTAssertEqual(expectedOptional, method.args.optional)
                XCTAssertEqual(expectedSplatted, method.args.splatted)
                return .nilObject
            }

            try Ruby.call(func_f, args: expectedM1 + expectedOptional + expectedSplatted + expectedM2)
        }
    }

    // Mandatory keyword arg
    func testSimpleMandatoryKeywordArg() {
        doErrorFree {
            let argKey = "ar"
            let func_f = "f"
            // def f(ar:)
            let spec_f = RbMethodArgsSpec(mandatoryKeywords: [argKey])
            let expectedVal = 211.4896
            var called = false

            try Ruby.defineGlobalFunction(name: func_f, argsSpec: spec_f) { _, method in
                method.checkArgs()
                XCTAssertEqual(1, method.args.keyword.count)
                guard let arg = method.args.keyword[argKey] else {
                    XCTFail("Arg for \(argKey) missing")
                    return .nilObject
                }
                XCTAssertEqual(expectedVal, Double(arg))
                XCTAssertFalse(called)
                called = true
                return .nilObject
            }

            try Ruby.call(func_f, kwArgs: [argKey : expectedVal])
            XCTAssertTrue(called)
        }
    }

    // Mandatory keyword arg - error cases
    func testErrorMandatoryKeywordArg() {
        doErrorFree {
            let argKey = "ar"
            let func_f = "f"
            // def f(ar:)
            let spec_f = RbMethodArgsSpec(mandatoryKeywords: [argKey])

            try Ruby.defineGlobalFunction(name: func_f, argsSpec: spec_f) { _, method in
                XCTFail("Ought to have failed parse")
                return .nilObject
            }

            // missing kw
            doError {
                try Ruby.call(func_f)
            }

            // extraneous kw
            doError {
                try Ruby.call(func_f, kwArgs: [argKey : 1, "foo": 5.3, "bar": "Sandwich"])
            }

            // a data hash instead of a kw hash
            doError {
                try Ruby.call(func_f, args: [[1:2]])
            }

            // a string instead of a hash of any kind
            doError {
                try Ruby.call(func_f, args: ["bucket"])
            }
        }
    }

    // Optional keyword args
    func testOptionalKeywordArgs() {
        doErrorFree {
            // def f(a: "fish")
            let func_f = "f"
            let f_opt_arg_kw = "a"
            let f_opt_arg_def = "fish"
            let spec_f = RbMethodArgsSpec(optionalKeywordValues: [f_opt_arg_kw: f_opt_arg_def])

            var expect_arg_val = ""
            try Ruby.defineGlobalFunction(name: func_f, argsSpec: spec_f) { _, method in
                method.checkArgs()
                XCTAssertEqual(expect_arg_val, String(method.args.keyword[f_opt_arg_kw]!))
                return .nilObject
            }

            expect_arg_val = f_opt_arg_def
            try Ruby.call(func_f)

            let overridden = "bucket"
            expect_arg_val = overridden
            try Ruby.call(func_f, kwArgs: [f_opt_arg_kw: overridden])
        }
    }

    // Explicit nil vs. keyword args hash ambiguity
    func testNilKeywordArgs() {
        doErrorFree {
            // def f(a, b:3)
            let func_f = "f"
            let kw_b = "b"
            let kw_b_def = 3
            let spec_f = RbMethodArgsSpec(leadingMandatoryCount: 1, optionalKeywordValues: [kw_b: kw_b_def])

            var expect_a = ""

            try Ruby.defineGlobalFunction(name: func_f, argsSpec: spec_f) { _, method in
                method.checkArgs()
                XCTAssertEqual(expect_a, String(method.args.mandatory[0]))
                XCTAssertEqual(kw_b_def, Int(method.args.keyword[kw_b]!))
                return .nilObject
            }

            // No kw hash, last mando arg is nil -> invent nil & use default.
            expect_a = ""
            try Ruby.call(func_f, args: [nil])

            // Explicit nil for kw hash -> consume it, no complaints, use default.
            expect_a = "fish"
            try Ruby.call(func_f, args: ["fish", nil])
        }
    }

    // Check compatibility with actual Ruby
    func testRubyCompatibility() {
        doErrorFree {
            try Ruby.require(filename: Helpers.fixturePath("swift_methods.rb"))

            // def swift_kwargs(a:, b:, c: 2, d: 3)
            let swift_kwargs_spec = RbMethodArgsSpec(mandatoryKeywords: ["a", "b"],
                                                     optionalKeywordValues: ["c" : 2, "d" : 3])
            try Ruby.defineGlobalFunction(name: "swift_kwargs", argsSpec: swift_kwargs_spec) { _, method in
                method.checkArgs()
                return method.args.keyword["a"]! +
                    method.args.keyword["b"]! +
                    method.args.keyword["c"]! +
                    method.args.keyword["d"]!
            }

            let testSuffixes = [9, 20, 14, 100, 200]
            try testSuffixes.forEach { val in
                let funcName = "ruby_kw_should_return_\(val)"
                let result = try Ruby.call(funcName)
                XCTAssertEqual(val, Int(result))
            }
        }
    }

    // Ruby confusion corner case, internals
    func testBadArgsHash() {
        doError {
            let spec = RbMethodArgsSpec()
            let _ = try spec.resolveKeywords(passed: RbObject(2))
        }
    }

    static var allTests = [
        ("testFixedArgsRoundTrip", testFixedArgsRoundTrip),
        ("testVarArgsRoundTrip", testVarArgsRoundTrip),
        ("testArgcMismatch", testArgcMismatch),
        ("testGoodBlock", testGoodBlock),
        ("testErrorNoBlock", testErrorNoBlock),
        ("testManualBlock", testManualBlock),
        ("testBlockArgs", testBlockArgs),
        ("testBlockBreakReturn", testBlockBreakReturn),
        ("testMandatoryArgCount", testMandatoryArgCount),
        ("testOptionalArgs", testOptionalArgs),
        ("testSplatArgs", testSplatArgs),
        ("testSplatMandatoryArgError", testSplatMandatoryArgError),
        ("testAllPositionalArgTypes", testAllPositionalArgTypes),
        ("testSimpleMandatoryKeywordArg", testSimpleMandatoryKeywordArg),
        ("testErrorMandatoryKeywordArg", testErrorMandatoryKeywordArg),
        ("testOptionalKeywordArgs", testOptionalKeywordArgs),
        ("testNilKeywordArgs", testNilKeywordArgs),
        ("testRubyCompatibility", testRubyCompatibility),
        ("testBadArgsHash", testBadArgsHash)
    ]
}
