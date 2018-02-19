//
//  CRubyMacros.swift
//  TMLRuby
//
//  Created by John Fairhurst on 15/02/2018.
//

import CRuby
import RubyBridgeHelpers

//
// Various useful stuff from ruby.h that didn't make it through the Clang importer.
//
// Mostly to do with numeric types, stuffing into and out of FIXNUM format, plus
// type-reasoning macros.
// Punt to C to get the actual platform macro for stuff dependent on integer widths.
//
// Began keeping this in the same order as ruby.h but good grief the numeric functions
// drove me crazy this way -- so reordered to group all like stuff together.
//
// RubyBridge uses the NUM abstraction layers exclusively so most stuff lower than that
// is omitted.
//

// MARK: - Integer conversions

// From platform to NUM -- BIGNUM or FIXNUM depending on size.

func RB_SHORT2NUM(_ v: Int16) -> VALUE   { return RB_INT2NUM(Int32(v)) }
func RB_USHORT2NUM(_ v: UInt16) -> VALUE { return RB_UINT2NUM(UInt32(v)) }
func RB_INT2NUM(_ v: Int32) -> VALUE     { return rbb_RB_INT2NUM(v) }
func RB_UINT2NUM(_ v: UInt32) -> VALUE   { return rbb_RB_UINT2NUM(v) }
func RB_LONG2NUM(_ x: Int) -> VALUE      { return rb_long2num_inline(x) }
func RB_ULONG2NUM(_ x: UInt) -> VALUE    { return rb_ulong2num_inline(x) }
func LL2NUM(_ v: Int64) -> VALUE         { return rb_ll2inum(v) } /* Consistent with Ruby's inconsistency ;) */
func ULL2NUM(_ v: UInt64) -> VALUE       { return rb_ull2inum(v) }

// From NUM to platform -- will raise exception if won't fit, need to
// push these all into _protect layer (or just LL and check on Swift size.)
// Rubyish - will call #to_i if no obvious conversion.

func RB_NUM2SHORT(_ x: VALUE) -> Int16   { return rb_num2short_inline(x) }
func RB_NUM2USHORT(_ x: VALUE) -> UInt16 { return rb_num2ushort(x) }
func RB_NUM2INT(_ x: VALUE) -> Int32     { return rbb_RB_NUM2INT(x) }
func RB_NUM2UINT(_ x: VALUE) -> UInt32   { return rbb_RB_NUM2UINT(x) }
func RB_NUM2LONG(_ x: VALUE) -> Int      { return rb_num2long_inline(x) }
func RB_NUM2ULONG(_ x: VALUE) -> UInt    { return rb_num2ulong_inline(x) }
func RB_NUM2LL(_ x: VALUE) -> Int64      { return rb_num2ll_inline(x) }
func RB_NUM2ULL(_ x: VALUE) -> UInt64    { return rb_num2ull(x) }

// MARK: - Floating point conversions

// From NUM to platform -- will raise exception if won't fit.
// Rubyish - will call `#to_f` if no obvious conversion.
func NUM2DBL(_ x: VALUE) -> Double { return rb_num2dbl(x) }

// From platform to NUM -- FLONUM or CLASS(FLOAT) depending
func DBL2NUM(_ dbl: Double) -> VALUE { return rb_float_new(dbl) }

// MARK: - Useful VALUE constants and macros

let Qfalse: VALUE = VALUE(RUBY_Qfalse.rawValue)
let Qtrue: VALUE = VALUE(RUBY_Qtrue.rawValue)
let Qnil: VALUE = VALUE(RUBY_Qnil.rawValue)
let Qundef: VALUE = VALUE(RUBY_Qundef.rawValue)

/// Is a `VALUE` truthy?
func RB_TEST(_ v: VALUE) -> Bool {
    return !((v & VALUE(~Qnil)) == 0)
}

/// Is a `VALUE` equal to `nil`?  You probably want `!RB_TEST()` instead.
func RB_NIL_P(_ v: VALUE) -> Bool {
    return !(v != Qnil)
}

// Not sure this one is useful
func CLASS_OF(_ v: VALUE) -> VALUE {
    return rb_class_of(v)
}

// MARK: - String utilities

// TODO: Make this all safe + delete the unwanted APIs

/// Do a `#to_s` on some object.  Raise if not possible.
/// Replaces the passed-in VALUE with the `to_s` result and returns the new value.
func StringValue(_ v: inout VALUE) -> VALUE {
    return rbb_StringValue(&v)
}

/// Call `StringValue` and then give pointer to raw string buffer.
/// If the passed-in value is not a string then it is replaced with the converted string.
func StringValuePtr(_ v: inout VALUE) -> UnsafePointer<Int8>! {
    return rbb_StringValuePtr(&v)
}

/// Call `StringValue`, check string buffer has no NULs and return it.  Raises on error.
/// If the passed-in value is not a string then it is replaced with the converted string.
func StringValueCStr(_ v: inout VALUE) -> UnsafePointer<Int8>! {
    return rbb_StringValueCStr(&v)
}

/// Number of bytes in the string.
func RSTRING_LEN(_ str: VALUE) -> Int {
    return rbb_RSTRING_LEN(str)
}

/// Address of the string byte buffer.
func RSTRING_PTR(_ str: VALUE) -> UnsafePointer<Int8> {
    return rbb_RSTRING_PTR(str)
}

// MARK: - More enum-y `VALUE` type enum

// Swift-friendly value type.  Constants duplicated from Ruby headers,
// should be low-risk.
public enum RbType: Int32 {
    case T_NONE     = 0x00

    case T_OBJECT   = 0x01
    case T_CLASS    = 0x02
    case T_MODULE   = 0x03
    case T_FLOAT    = 0x04
    case T_STRING   = 0x05
    case T_REGEXP   = 0x06
    case T_ARRAY    = 0x07
    case T_HASH     = 0x08
    case T_STRUCT   = 0x09
    case T_BIGNUM   = 0x0a
    case T_FILE     = 0x0b
    case T_DATA     = 0x0c
    case T_MATCH    = 0x0d
    case T_COMPLEX  = 0x0e
    case T_RATIONAL = 0x0f

    case T_NIL      = 0x11
    case T_TRUE     = 0x12
    case T_FALSE    = 0x13
    case T_SYMBOL   = 0x14
    case T_FIXNUM   = 0x15
    case T_UNDEF    = 0x16

    case T_IMEMO    = 0x1a
    case T_NODE     = 0x1b
    case T_ICLASS   = 0x1c
    case T_ZOMBIE   = 0x1d
}

func TYPE(_ x: VALUE) -> RbType {
    return RbType(rawValue: rb_type(x)) ?? .T_UNDEF
}

// MARK: - Testing whether a `VALUE` is of a particular type

func RB_FIXNUM_P(_ f: VALUE) -> Bool {
    return (f & VALUE(RUBY_FIXNUM_FLAG.rawValue)) != 0
}

func RB_IMMEDIATE_P(_ x: VALUE) -> Bool {
    return (x & VALUE(RUBY_IMMEDIATE_MASK.rawValue)) != 0
}

func RB_STATIC_SYM_P(_ x: VALUE) -> Bool {
    //#define RB_STATIC_SYM_P(x) (((VALUE)(x)&~((~(VALUE)0)<<RUBY_SPECIAL_SHIFT)) == RUBY_SYMBOL_FLAG)
    return (x & ((1<<RUBY_SPECIAL_SHIFT.rawValue)-1)) == RUBY_SYMBOL_FLAG.rawValue
}

func RB_DYNAMIC_SYM_P(_ x: VALUE) -> Bool {
    return !RB_SPECIAL_CONST_P(x) && RB_BUILTIN_TYPE(x) == RUBY_T_SYMBOL.rawValue
}

func RB_SYMBOL_P(_ x: VALUE) -> Bool {
    return RB_STATIC_SYM_P(x) || RB_DYNAMIC_SYM_P(x)
}

func RB_FLONUM_P(_ x: VALUE) -> Bool {
    return (x & VALUE(RUBY_FLONUM_MASK.rawValue)) == RUBY_FLONUM_FLAG.rawValue
}

func RB_FLOAT_TYPE_P(_ obj: VALUE) -> Bool {
    return RB_FLONUM_P(obj) ||
        (!RB_SPECIAL_CONST_P(obj) && RB_BUILTIN_TYPE(obj) == RUBY_T_FLOAT.rawValue)
}

func RB_SPECIAL_CONST_P(_ x: VALUE) -> Bool {
    return RB_IMMEDIATE_P(x) || !RB_TEST(x)
}

func RB_BUILTIN_TYPE(_ x: VALUE) -> Int32 {
    return rbb_RB_BUILTIN_TYPE(x)
}

func RB_TYPE_P(_ obj: VALUE, _ type: RbType) -> Bool {
    switch type {
    case .T_FIXNUM: return RB_FIXNUM_P(obj)
    case .T_TRUE:   return obj == Qtrue
    case .T_FALSE:  return obj == Qfalse
    case .T_NIL:    return obj == Qnil
    case .T_UNDEF:  return obj == Qundef
    case .T_SYMBOL: return RB_SYMBOL_P(obj)
    case .T_FLOAT:  return RB_FLOAT_TYPE_P(obj)
    default:
        return !RB_SPECIAL_CONST_P(obj) && RB_BUILTIN_TYPE(obj) == type.rawValue
    }
}
//#define RB_TYPE_P(obj, type) ( \
//((type) == RUBY_T_FIXNUM) ? RB_FIXNUM_P(obj) : \
//((type) == RUBY_T_TRUE) ? ((obj) == RUBY_Qtrue) : \
//((type) == RUBY_T_FALSE) ? ((obj) == RUBY_Qfalse) : \
//((type) == RUBY_T_NIL) ? ((obj) == RUBY_Qnil) : \
//((type) == RUBY_T_UNDEF) ? ((obj) == RUBY_Qundef) : \
//((type) == RUBY_T_SYMBOL) ? RB_SYMBOL_P(obj) : \
//((type) == RUBY_T_FLOAT) ? RB_FLOAT_TYPE_P(obj) : \
//(!RB_SPECIAL_CONST_P(obj) && RB_BUILTIN_TYPE(obj) == (type)))

// MARK: - Garbage collection helpers

// TODO: figure out
//#define RB_OBJ_WB_UNPROTECT(x)      rb_obj_wb_unprotect(x, __FILE__, __LINE__)
//#define RB_OBJ_WRITE(a, slot, b)       rb_obj_write((VALUE)(a), (VALUE *)(slot),(VALUE)(b), __FILE__, __LINE__)

// MARK: - Not sure if we will need these

func RB_ID2SYM(_ x: ID) -> VALUE {
    return rb_id2sym(x)
}

func RB_SYM2ID(_ x: VALUE) -> ID {
    return rb_sym2id(x)
}

// MARK: - Low-level FIXNUM manipulation

// Probably don't need these any more.

/// The signed-integer type of the same width as `VALUE`
typealias SIGNED_VALUE = Int

let RUBY_FIXNUM_MAX = SIGNED_VALUE.max >> 1
let RUBY_FIXNUM_MIN = SIGNED_VALUE.min >> 1

func RB_LONG2FIX(_ i: Int) -> VALUE {
    return (VALUE(bitPattern: i) << 1) | VALUE(RUBY_FIXNUM_FLAG.rawValue)
}

func RB_FIX2LONG(_ v: VALUE) -> Int {
    return rb_fix2long(v)
}

func RB_FIX2ULONG(_ v: VALUE) -> UInt {
    return rb_fix2ulong(v)
}

func RB_POSFIXABLE(_ f: SIGNED_VALUE) -> Bool {
    return f < RUBY_FIXNUM_MAX + 1
}

func RB_NEGFIXABLE(_ f: SIGNED_VALUE) -> Bool {
    return f >= RUBY_FIXNUM_MIN
}

func RB_FIXABLE(_ f: SIGNED_VALUE) -> Bool {
    return RB_POSFIXABLE(f) && RB_NEGFIXABLE(f)
}
