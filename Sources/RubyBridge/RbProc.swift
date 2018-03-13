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
