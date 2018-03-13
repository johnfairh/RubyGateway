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
}

private func rbproc_block_callback(yielded_arg: VALUE,
                                   rawContext: UnsafeMutableRawPointer?,
                                   argc: Int32, argv: UnsafePointer<VALUE>,
                                   blockarg: VALUE) -> VALUE {
    guard let rawContext = rawContext else {
        fatalError("Bang")
    }
    let context = Unmanaged<RbProcContext>.fromOpaque(rawContext).takeUnretainedValue()
    let obj = context.procCallback([])
    return obj.withRubyValue { $0 }
}

public struct RbProc {

    internal static func doBlockCall(value: VALUE, methodId: ID, argValues: [VALUE], procCallback: ProcCallback) throws -> VALUE {
        return try withoutActuallyEscaping(procCallback) { escapable in
            let context = RbProcContext(procCallback: escapable)
            let unmanaged = Unmanaged.passRetained(context)
            defer { unmanaged.release() }
            return try RbVM.doProtect {
                rbb_block_call_protect(value, methodId,
                                       Int32(argValues.count), argValues,
                                       rbproc_block_callback, unmanaged.toOpaque(),
                                       nil)
            }
        }
    }
}
