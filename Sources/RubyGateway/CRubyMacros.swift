//
//  CRubyMacros.swift
//  RubyGateway
//
//  Distributed under the MIT license, see LICENSE
//  Portions of this file derived from Ruby and distributed under terms of its license.

import CRuby
import RubyGatewayHelpers

//
// Various useful stuff from ruby.h that didn't make it through the Clang importer.
//
// Mostly to do with numeric types, stuffing into and out of FIXNUM format, plus
// type-reasoning macros.
//
// Began keeping this in the same order as ruby.h but good grief the numeric functions
// drove me crazy this way -- so reordered to group all like stuff together.
//
// RubyGateway uses the NUM abstraction layers exclusively so most stuff lower than that
// is omitted.
//

// MARK: - Integer conversions

// From platform to NUM -- BIGNUM or FIXNUM depending on size.

func RB_LONG2NUM(_ x: Int) -> VALUE      { return rb_long2num_inline(x) }
func RB_ULONG2NUM(_ x: UInt) -> VALUE    { return rb_ulong2num_inline(x) }

// MARK: - Floating point conversions

// From platform to NUM -- FLONUM or CLASS(FLOAT) depending
func DBL2NUM(_ dbl: Double) -> VALUE { return rb_float_new(dbl) }

// MARK: - Useful VALUE constants and macros

let Qfalse: VALUE = VALUE(rbg_qfalse())
let Qtrue: VALUE = VALUE(rbg_qtrue())
let Qnil: VALUE = VALUE(rbg_qnil())
let Qundef: VALUE = VALUE(rbg_qundef())

// MARK: - More enum-y `VALUE` type enum

// Swift-friendly value type.  Constants duplicated from Ruby headers,
// can't see how not to.  Ruby 3 moves to an actual enum that Swift managers
// to import so eventually this will go away.

/// The type of a Ruby VALUE as wrapped by `RbObject`.
///
/// Not generally useful, maybe for debugging.
public enum RbType: Int32 {
    /// RUBY_T_NONE
    case T_NONE     = 0x00

    /// RUBY_T_OBJECT
    case T_OBJECT   = 0x01
    /// RUBY_T_CLASS
    case T_CLASS    = 0x02
    /// RUBY_T_MODULE
    case T_MODULE   = 0x03
    /// RUBY_T_FLOAT
    case T_FLOAT    = 0x04
    /// RUBY_T_STRING
    case T_STRING   = 0x05
    /// RUBY_T_REGEXP
    case T_REGEXP   = 0x06
    /// RUBY_T_ARRAY
    case T_ARRAY    = 0x07
    /// RUBY_T_HASH
    case T_HASH     = 0x08
    /// RUBY_T_STRUCT
    case T_STRUCT   = 0x09
    /// RUBY_T_BIGNUM
    case T_BIGNUM   = 0x0a
    /// RUBY_T_FILE
    case T_FILE     = 0x0b
    /// RUBY_T_DATA
    case T_DATA     = 0x0c
    /// RUBY_T_MATCH
    case T_MATCH    = 0x0d
    /// RUBY_T_COMPLEX
    case T_COMPLEX  = 0x0e
    /// RUBY_T_RATIONAL
    case T_RATIONAL = 0x0f

    /// RUBY_T_NIL
    case T_NIL      = 0x11
    /// RUBY_T_TRUE
    case T_TRUE     = 0x12
    /// RUBY_T_FALSE
    case T_FALSE    = 0x13
    /// RUBY_T_SYMBOL
    case T_SYMBOL   = 0x14
    /// RUBY_T_FIXNUM
    case T_FIXNUM   = 0x15
    /// RUBY_T_UNDEF
    case T_UNDEF    = 0x16

    /// RUBY_T_IMEMO
    case T_IMEMO    = 0x1a
    /// RUBY_T_NODE
    case T_NODE     = 0x1b
    /// RUBY_T_ICLASS
    case T_ICLASS   = 0x1c
    /// RUBY_T_ZOMBIE
    case T_ZOMBIE   = 0x1d
    /// RUBY_T_MOVED
    case T_MOVED    = 0x1e
}

func TYPE(_ x: VALUE) -> RbType {
    RbType(rawValue: rbg_type(x)) ?? .T_UNDEF
}

// MARK: - Garbage collection helpers

//#define RB_OBJ_WB_UNPROTECT(x)      rb_obj_wb_unprotect(x, __FILE__, __LINE__)
//#define RB_OBJ_WRITE(a, slot, b)       rb_obj_write((VALUE)(a), (VALUE *)(slot),(VALUE)(b), __FILE__, __LINE__)
