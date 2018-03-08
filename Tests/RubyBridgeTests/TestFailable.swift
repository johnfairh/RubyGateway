//
//  TestFailable.swift
//  RubyBridgeTests
//
//  Distributed under the MIT license, see LICENSE
//

import XCTest
import RubyBridge

class TestFailable: XCTestCase {
    /// get the ruby code
    private func setup() {
        try! Ruby.require(filename: Helpers.fixturePath("endtoend.rb"))
    }

    private func getInstance() -> RbObject {
        return RbObject(ofClass: "RubyBridge::EndToEnd",
                        args: [1.2],
                        kwArgs: [("name", "barney")])!
    }

    // Constants
    func testConstants() {
        setup()

        guard let mod = Ruby.failable.getConstant("RubyBridge"),
            let cls = mod.failable.getClass("EndToEnd") else {
                XCTFail("Couldn't get mod + cls")
                return
        }

        if let const = cls.failable.getConstant("Nope") {
            XCTFail("Managed to get 'Nope': \(const)")
        }
    }

    // Call, attrs
    func testCallAttrs() {
        setup()

        let inst = getInstance()

        guard let name = inst.failable.getAttribute("name"),
            let _ = inst.failable.setAttribute("name", newValue: "New \(name)") else {
                XCTFail("Couldn't set attribute")
                return
        }

        guard let _ = inst.failable.call("to_s"),
            let _ = inst.failable.get("to_s") else {
                XCTFail("Couldn't get/call to_s")
                return
        }

        if let res = inst.failable.call("no_method") {
            XCTFail("Managed to call no_method: \(res)")
            return
        }

        guard let _ = inst.failable.call(symbol: RbSymbol("to_s")) else {
            XCTFail("Couldn't call via symbol")
            return
        }
    }

    // ivars
    func testIvars() {
        setup()

        let inst = getInstance()

        let ivar = "@ivname"

        guard let val = inst.failable.getInstanceVar(ivar) else {
            XCTFail("Couldn't get \(ivar)")
            return
        }
        XCTAssertTrue(val.isNil)

        guard let _ = inst.failable.setInstanceVar(ivar, newValue: 3.14) else {
            XCTFail("Managed to get a failure from setinstancevar")
            return
        }

        if let val = inst.failable.getInstanceVar("bad-name") {
            XCTFail("Used bad ivar name: \(val)")
            return
        }
    }

    // cvars
    func testCvars() {
        setup()

        guard let clazz = Ruby.failable.getClass("RubyBridge::EndToEnd") else {
            XCTFail("Couldn't get class")
            return
        }

        let cvar = "@@mycvar"

        if let cv = clazz.failable.getClassVar(cvar) {
            XCTFail("Got invalid Cvar: \(cv)")
            return
        }

        let cvarVal = 103

        guard let _ = clazz.failable.setClassVar(cvar, newValue: cvarVal),
            let reRead = clazz.failable.getClassVar(cvar) else {
                XCTFail("Failed to set/get cvar")
                return
        }
        XCTAssertEqual(cvarVal, Int(reRead))
    }

    // globals
    func testGlobals() {
        setup()

        let gvar = "$mygvar"

        if let gvarVal = Ruby.failable.getGlobalVar("bad_name") {
            XCTFail("Managed to get badly named gvar: \(gvarVal)")
            return
        }

        guard let val = Ruby.failable.getGlobalVar(gvar) else {
            XCTFail("Couldn't get \(gvar)")
            return
        }
        XCTAssertTrue(val.isNil)

        let newVal = "NewGVarVal"

        guard let _ = Ruby.failable.setGlobalVar(gvar, newValue: newVal),
            let reRead = Ruby.failable.getGlobalVar(gvar) else {
                XCTFail("Failed to set/get gvar")
                return
        }
        XCTAssertEqual(newVal, String(reRead))
    }
}
