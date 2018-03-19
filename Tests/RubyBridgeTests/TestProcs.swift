//
//  TestProcs.swift
//  RubyBridgeTests
//
//  Distributed under the MIT license, see LICENSE
//

import XCTest
@testable /* checkIsProc */ import RubyBridge

/// Proc tests
class TestProcs: XCTestCase {

    /// Manual proc creation
    func testManualProc() {
        do {
            var procHappened = false

            guard let proc = (RbObject(ofClass: "Proc", retainBlock: true) { args in
                procHappened = true
                return .nilObject
            }) else {
                XCTFail("Couldn't create proc")
                return
            }

            try proc.call("call")
            XCTAssertTrue(procHappened)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    /// Create and call simple swift proc
    func testCall() {
        do {
            let expectedArg0 = "argString"
            let expectedArg1 = 102.8
            let expectedArgCount = 2
            let expectedResult = -7002

            let proc = RbObject() { args in
                XCTAssertEqual(expectedArgCount, args.count)
                XCTAssertEqual(expectedArg0, String(args[0]))
                XCTAssertEqual(expectedArg1, Double(args[1]))
                return RbObject(expectedResult)
            }

            let result = try proc.rubyObject.call("call", args: [expectedArg0, expectedArg1])

            XCTAssertEqual(expectedResult, Int(result))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    /// Proc detection
    func testNotProc() {
        let proc = RbObject() { args in .nilObject }
        print(proc)
        let object = proc.rubyObject
        do {
            try object.checkIsProc()
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        do {
            try RbObject.nilObject.checkIsProc()
            XCTFail("Believe nil is proc")
        } catch RbError.badType(_) {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    /// Failable proc conversion
    func testProcConversion() {
        if let nilProc = RbProc(RbObject.nilObject) {
            XCTFail("Managed to wrap 'nil' in a proc: \(nilProc)")
            return
        }

        guard let symproc = RbProc(RbSymbol("something").rubyObject) else {
            XCTFail("Couldn't recognize symbol as to_proc supporting")
            return
        }
        print(symproc)
    }

    /// Procs from Ruby objects - success
    func testRubyObjectProc() {
        do {
            /// assertSame( "AAA", Array("aaa").map(&:upcase).pop )
            let testStr = "aaa"

            let symproc = RbProc(object: RbSymbol("upcase"))

            let array = try Ruby.call("Array", args: [testStr])

            let mappedArr = try array.call("map", block: symproc)

            let mappedVal = try mappedArr.call("pop")

            XCTAssertEqual(testStr.uppercased(), String(mappedVal))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    /// Procs from Ruby objects - fail
    func testRubyObjectProcFail() {
        do {
            let notAProc = RbProc(object: "upcase")

            let array = try Ruby.call("Array", args: [1])

            do {
                let mappedArr = try array.call("map", block: notAProc)
                XCTFail("Managed to procify a string: \(mappedArr)")
            } catch {
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    /// Exception cases:
    /// 1) RbError.rubyException thrown.  Propagate.
    /// 1b) RbException thrown.  Propagate.
    /// 2) Some other Error thrown.  Raise fresh Ruby exception
    /// 3) 'break' issued.  Do 'break' thing.

    /// 1) Cause Ruby to raise exception by calling from Swift PRoc
    ///      -> Detect and convert to Swift RbError
    ///      -> Catch that and re-raise Ruby exception
    ///      -> Detect that and convert to Swift RbError again,
    ///         wrapping original Ruby exception.
    func testProcRubyException() {
        do {
            let badString = "Nope"

            let proc = RbObject() { args in
                // call nonexistant method -> NoMethodError mentioning `badString`
                try args[0].call(badString)
            }

            do {
                try proc.rubyObject.call("call", args: [120])
                XCTFail("Managed to survive call to throwing proc")
            } catch RbError.rubyException(let exn) {
                // catch the NoMethodError, hopefully
                XCTAssertTrue(exn.description.contains(badString))
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    /// 1b - throw 'ruby' exception from Swift
    func testProcRubyException2() {
        do {
            let msg = "Ruby Exception!"

            let proc = RbObject() { args in
                throw RbException(message: msg)
            }

            do {
                try proc.rubyObject.call("call")
                XCTFail("Managed to survive call to throwing proc")
            } catch RbError.rubyException(let exn) {
                // catch the RbException, hopefully
                XCTAssertTrue(exn.description.contains(msg))
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    /// 2) Some other Error thrown.
    func testProcWeirdException() {
        struct S: Error {}
        do {
            let proc = RbObject() { args in
                throw S()
            }

            do {
                try proc.rubyObject.call("call")
                XCTFail("Managed to survive call to throwing proc")
            } catch RbError.rubyException(let exn) {
                print("Got Ruby exception \(exn)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    /// 3) Break.
    func testProcBreak() {
        do {
            let array = try Ruby.call("Array", args: [1])
            try array.call("push", args: [2, 3])

            var counter = 0

            let retVal = try array.call("each") { args in
                counter += 1
                if args[0] == 2 {
                    throw RbBreak()
                }
                return .nilObject
            }

            XCTAssertEqual(2, counter) // break forced iter to end early
            XCTAssertEqual(RbObject.nilObject, retVal)

            // Now try breaking with a value
            counter = 0

            let breakVal = "Answer"

            let retVal2 = try array.call("each") { args in
                counter += 1
                if args[0] == 2 {
                    throw RbBreak(with: breakVal)
                }
                return .nilObject
            }

            XCTAssertEqual(2, counter)
            XCTAssertEqual(breakVal, String(retVal2))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // Lambda experiments
    func testLambda() {
        do {
            let lambda = try Ruby.call("lambda", blockRetention: .returned) { args in
                if args.count != 2 {
                    throw RbException(message: "Wrong number of args, expected 2 got \(args.count)")
                }
                return args[0] + args[1]
            }

            let result = try lambda.call("call", args: [1,2])
            XCTAssertEqual(3, Int(result))

            do {
                let result2 = try lambda.call("call", args: [1])
                XCTFail("Managed to call lambda with insufficient args: \(result2)")
            } catch {
                print(error)
            }
        } catch {
            XCTFail("Unexpected exception: \(error)")
        }
    }

    static var allTests = [
        ("testManualProc", testManualProc),
        ("testCall", testCall),
        ("testNotProc", testNotProc),
        ("testProcConversion", testProcConversion),
        ("testRubyObjectProc", testRubyObjectProc),
        ("testRubyObjectProcFail", testRubyObjectProcFail),
        ("testProcRubyException", testProcRubyException),
        ("testProcRubyException2", testProcRubyException2),
        ("testProcWeirdException", testProcWeirdException),
        ("testProcBreak", testProcBreak),
        ("testLambda", testLambda)
    ]
}
