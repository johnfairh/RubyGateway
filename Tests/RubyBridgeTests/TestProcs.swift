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

    /// Create and call simple swift proc
    func testCall() {
        do {
            let expectedArg0 = "argString"
            let expectedArg1 = 102.8
            let expectedArgCount = 2
            let expectedResult = -7002

            let proc = RbProc() { args in
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
        let proc = RbProc() { args in .nilObject }
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

            let proc = RbProc() { args in
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

            let proc = RbProc() { args in
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
            let proc = RbProc() { args in
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

    static var allTests = [
        ("testCall", testCall),
        ("testNotProc", testNotProc),
        ("testProcConversion", testProcConversion),
        ("testRubyObjectProc", testRubyObjectProc),
        ("testRubyObjectProcFail", testRubyObjectProcFail),
        ("testProcRubyException", testProcRubyException),
        ("testProcRubyException2", testProcRubyException2),
        ("testProcWeirdException", testProcWeirdException)
    ]
}