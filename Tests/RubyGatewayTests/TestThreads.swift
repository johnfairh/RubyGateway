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

    final class Wrp: @unchecked Sendable {
        var threadHasRun: Bool
        init() { threadHasRun = false }
    }

    // Check Ruby threads + GVL works as expected
    func testCreateThread() {
        doErrorFree {
            let threadHasRun = Wrp()
            let threadObj = RbThread.create {
                XCTAssertTrue(RbThread.isRubyThread())
                XCTAssertFalse(threadHasRun.threadHasRun)
                let obj: RbObject = [1,2,3]
                print("Other thread ending: \(obj)")
                threadHasRun.threadHasRun = true
            }
            XCTAssertTrue(RbThread.isRubyThread())
            if let threadObj = threadObj {
                try threadObj.call("join")
                XCTAssertTrue(threadHasRun.threadHasRun)
            } else {
                XCTFail("Couldn't create thread object")
            }
        }
    }

    // Check Ruby-created thread can drop GVL
    func testThreadCanDropGvl() {
        doErrorFree {
            let threadHasRun = Wrp()
            let threadObj = RbThread.create {
                XCTAssertFalse(threadHasRun.threadHasRun)
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

                threadHasRun.threadHasRun = true
            }
            if let threadObj = threadObj {
                try threadObj.call("join")
                XCTAssertTrue(threadHasRun.threadHasRun)
            } else {
                XCTFail("Couldn't create thread object")
            }
        }
    }

    final class Wrp2: @unchecked Sendable {
        var sleeping: Bool
        var slept: Bool
        var pid: pthread_t?

        init() {
            sleeping = false
            slept = false
            pid = nil
        }
    }

    // Check interrupt works outwith GVL using UBF_IO
    func testThreadCanBeInterruptedWithoutGvl() {
        doErrorFree {
            let wrp = Wrp2()

            let threadObj = RbThread.create(callback: {
                RbThread.callWithoutGvl(unblocking: .io) {
                    wrp.sleeping = true
                    let sleepRc = sleep(100)
                    XCTAssertNotEqual(0, sleepRc)  // means sleep(3) interrupted
                    wrp.slept = true
                }
            })!

            while !wrp.sleeping {
                try Ruby.call("sleep", args: [0.2])
            }

            // Without an unblocking function this kill is ignored
            try Ruby.get("Thread").call("kill", args: [threadObj])

            try threadObj.call("join")

            XCTAssertTrue(wrp.slept)
        }
    }

    // Check interrupt works outwith GVL doing it manually
    func testThreadCanBeInterruptedWithoutGvlManually() {
        doErrorFree {
            let wrp = Wrp2()

            let threadObj = RbThread.create(callback: {
                RbThread.callWithoutGvl(unblocking: .custom({ pthread_kill(wrp.pid!, SIGVTALRM) }),
                                        callback: {
                    wrp.pid = pthread_self()
                    wrp.sleeping = true
                    let sleepRc = sleep(100)
                    XCTAssertNotEqual(0, sleepRc)  // means sleep(3) interrupted
                    wrp.slept = true
                })
            })!

            while !wrp.sleeping {
                try Ruby.call("sleep", args: [0.2])
            }

            // Without an unblocking function this kill is ignored
            try Ruby.get("Thread").call("kill", args: [threadObj])

            try threadObj.call("join")

            XCTAssertTrue(wrp.slept)
        }
    }
}
