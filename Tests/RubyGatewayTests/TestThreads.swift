//
//  TestThreads.swift
//  RubyGatewayTests
//
//  Distributed under the MIT license, see LICENSE
//

import XCTest
import RubyGateway
import Foundation

class TestThreads: XCTestCase {

    // Check Ruby threads + GVL works as expected
    func testCreateThread() {
        doErrorFree {
            var threadHasRun = false // optimistic concurrency control....
            let threadObj = RbThread.create {
                XCTAssertTrue(RbThread.isRubyThread())
                XCTAssertFalse(threadHasRun)
                let obj: RbObject = [1,2,3]
                print("Other thread ending: \(obj)")
                threadHasRun = true
            }
            XCTAssertTrue(RbThread.isRubyThread())
            if let threadObj = threadObj {
                try threadObj.call("join")
                XCTAssertTrue(threadHasRun)
            } else {
                XCTFail("Couldn't create thread object")
            }
        }
    }

    // Check Ruby-created thread can drop GVL
    func testThreadCanDropGvl() {
        doErrorFree {
            var threadHasRun = false // optimistic concurrency control....
            let threadObj = RbThread.create {
                XCTAssertFalse(threadHasRun)
                let obj: RbObject = [1, 2, 3]
                print("Other thread giving up GVL: \(obj)")

                RbThread.callWithoutGvl() {
                    print("Section without GVL")

                    RbThread.callWithGvl {
                        let obj2: RbObject = [4, 5, 6]
                        print("Back in Ruby: \(obj) \(obj2)")
                    }
                }

                print("Back in with GVL")

                threadHasRun = true
            }
            if let threadObj = threadObj {
                try threadObj.call("join")
                XCTAssertTrue(threadHasRun)
            } else {
                XCTFail("Couldn't create thread object")
            }
        }
    }

    // Check interrupt works outwith GVL using UBF_IO
    func testThreadCanBeInterruptedWithoutGvl() {
        doErrorFree {
            var sleeping = false
            var slept = false

            let threadObj = RbThread.create(callback: {
                RbThread.callWithoutGvl(unblocking: .io) {
                    sleeping = true
                    let sleepRc = sleep(100)
                    XCTAssertNotEqual(0, sleepRc)  // means sleep(3) interrupted
                    slept = true
                }
            })!

            while !sleeping {
                try Ruby.call("sleep", args: [0.2])
            }

            // Without an unblocking function this kill is ignored
            try Ruby.get("Thread").call("kill", args: [threadObj])

            try threadObj.call("join")

            XCTAssertTrue(slept)
        }
    }

    // Check interrupt works outwith GVL doing it manually
    func testThreadCanBeInterruptedWithoutGvlManually() {
        doErrorFree {
            var slept = false
            var sleeping = false
            var pid: pthread_t? = nil

            let threadObj = RbThread.create(callback: {
                RbThread.callWithoutGvl(unblocking: .custom({ pthread_kill(pid!, SIGVTALRM) }),
                                        callback: {
                    pid = pthread_self()
                    sleeping = true
                    let sleepRc = sleep(100)
                    XCTAssertNotEqual(0, sleepRc)  // means sleep(3) interrupted
                    slept = true
                })
            })!

            while !sleeping {
                try Ruby.call("sleep", args: [0.2])
            }

            // Without an unblocking function this kill is ignored
            try Ruby.get("Thread").call("kill", args: [threadObj])

            try threadObj.call("join")

            XCTAssertTrue(slept)
        }
    }
}
