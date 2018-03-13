//
//  RbProc.swift
//  RubyBridge
//
//  Distributed under the MIT license, see LICENSE
//

// 1. Box type to pass context through - function type or RbObject for PROC
// 2. Pull out parts of dance from objectaccess
// 3. Hook up rbb side
// 4. Write callback to unbox box and propagate call
// 5. Should be able to write a test
// 6. Figure out API for returning stuff back to Ruby, test various permutations
// 7. Attempt refactor as Proc + rb_yield_block

import CRuby
import RubyBridgeHelpers

internal typealias ProcCallback = ([RbObject]) -> RbObject

fileprivate class RbProcContext {
    let procCallback: ProcCallback

    init(procCallback: @escaping ProcCallback) {
        self.procCallback = procCallback
    }

    static func from(raw: UnsafeMutableRawPointer) -> RbProcContext {
        return Unmanaged<RbProcContext>.fromOpaque(raw).takeUnretainedValue()
    }

    func withRaw<T>(callback: (UnsafeMutableRawPointer) throws -> T) rethrows -> T {
        let unmanaged = Unmanaged.passRetained(self)
        defer { unmanaged.release() }
        return try callback(unmanaged.toOpaque())
    }
}

private func rbproc_block_callback(yielded_arg: VALUE,
                                   rawContext: UnsafeMutableRawPointer,
                                   argc: Int32, argv: UnsafePointer<VALUE>,
                                   blockarg: VALUE) -> VALUE {
    let context = RbProcContext.from(raw: rawContext)
    let obj = context.procCallback([])
    return obj.withRubyValue { $0 }
}

public struct RbProc {

    internal static func doBlockCall(value: VALUE, methodId: ID, argValues: [VALUE], procCallback: ProcCallback) throws -> VALUE {
        return try withoutActuallyEscaping(procCallback) { escapable in
            let context = RbProcContext(procCallback: escapable)
            return try context.withRaw { rawContext in
                return try RbVM.doProtect {
                    rbb_block_call_protect(value, methodId,
                                           Int32(argValues.count), argValues,
                                           rbproc_block_callback, rawContext,
                                           nil)
                }
            }
        }
    }
}
