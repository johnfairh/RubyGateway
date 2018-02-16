//
//  TestVM.swift
//  TMLRubyTests
//
//  Created by John Fairhurst on 13/02/2018.
//

import XCTest
import CRuby
import TMLRuby

class TestVM: XCTestCase {

    func testSanity() {
        print("Size of VALUE is \(SIZEOF_VALUE)")
        print("UInt.max is \(UInt.max)")
        print("PRI_VALUE_PREFIX is \(PRI_VALUE_PREFIX)")

        print("FIX_MAX is \(RUBY_FIXNUM_MAX)")
        print("FIX_MIN is \(RUBY_FIXNUM_MIN)")
    }

    /// Check we can bring up Ruby.
    func testInit() {
        let _ = Helpers.ruby
    }

    /// Check functional.
    func testRequire() {
        let _ = Helpers.ruby
        rb_require(Helpers.fixturePath("backwards.rb"))
        let string = "natural"
        var stringArg = rb_str_new_cstr(string)
        var result = rb_funcallv(0, rb_intern("backwards"), 1, &(stringArg))
        let str = rb_string_value_cstr(&(result))

        XCTAssertEqual(String(string.reversed()), String(cString: str!))
//
//        var state: Int32 = 0
//        rb_eval_string_protect("require 'pp'", &state);
//
//        rb_eval_string_protect("require 'rouge'", &state);
//
//        rb_eval_string_protect("require 'jazzy'", &state);
//
//        puts("The end")
    }

    /// Second init failure
    func testSecondInit() {
        let _ = Helpers.ruby

        do {
            let second = try RbVM()
            XCTFail("Should not have worked: \(second)")
        } catch RbError.initError(_) {
            // OK
        } catch {
            XCTFail("Unexpected error type")
        }
    }

    func testRequireException() {
        let vm = Helpers.ruby

        do {
            let rc = try vm.require(filename: "pddddp")
            XCTFail("vm.require unexpectedly passed, rc=\(rc)")
        } catch {
            print("Got expected exception: \(error)")
        }
    }

    static var allTests = [
        ("testInit", testInit),
    ]
}
