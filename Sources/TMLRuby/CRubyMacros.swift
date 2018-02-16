//
//  CRubyMacros.swift
//  TMLRuby
//
//  Created by John Fairhurst on 15/02/2018.
//

import CRuby
import TMLRubyHelpers

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
// TMLRuby uses the NUM abstraction layers exclusively so most stuff lower than that
// is omitted.
//

// MARK: - Integer conversions

// From platform to NUM -- BIGNUM or FIXNUM depending on size.

public func RB_SHORT2NUM(_ v: Int16) -> VALUE   { return RB_INT2NUM(Int32(v)) }
public func RB_USHORT2NUM(_ v: UInt16) -> VALUE { return RB_UINT2NUM(UInt32(v)) }
public func RB_INT2NUM(_ v: Int32) -> VALUE     { return tml_ruby_RB_INT2NUM(v) }
public func RB_UINT2NUM(_ v: UInt32) -> VALUE   { return tml_ruby_RB_UINT2NUM(v) }
public func RB_LONG2NUM(_ x: Int) -> VALUE      { return rb_long2num_inline(x) }
public func RB_ULONG2NUM(_ x: UInt) -> VALUE    { return rb_ulong2num_inline(x) }
public func LL2NUM(_ v: Int64) -> VALUE         { return rb_ll2inum(v) } /* Consistent with Ruby's inconsistency ;) */
public func ULL2NUM(_ v: UInt64) -> VALUE       { return rb_ull2inum(v) }

// From NUM to platform -- will raise exception if won't fit, need to
// push these all into _protect layer (or just LL and check on Swift size.)
// Rubyish - will call #to_i if no obvious conversion.

public func RB_NUM2SHORT(_ x: VALUE) -> Int16   { return rb_num2short_inline(x) }
public func RB_NUM2USHORT(_ x: VALUE) -> UInt16 { return rb_num2ushort(x) }
public func RB_NUM2INT(_ x: VALUE) -> Int32     { return tml_ruby_RB_NUM2INT(x) }
public func RB_NUM2UINT(_ x: VALUE) -> UInt32   { return tml_ruby_RB_NUM2UINT(x) }
public func RB_NUM2LONG(_ x: VALUE) -> Int      { return rb_num2long_inline(x) }
public func RB_NUM2ULONG(_ x: VALUE) -> UInt    { return rb_num2ulong_inline(x) }
public func RB_NUM2LL(_ x: VALUE) -> Int64      { return rb_num2ll_inline(x) }
public func RB_NUM2ULL(_ x: VALUE) -> UInt64    { return rb_num2ull(x) }

// MARK: - Floating point conversions

// From NUM to platform -- will raise exception if won't fit.
// Rubyish - will call `#to_f` if no obvious conversion.
public func NUM2DBL(_ x: VALUE) -> Double { return rb_num2dbl(x) }

// From platform to NUM -- FLONUM or CLASS(FLOAT) depending
public func DBL2NUM(_ dbl: Double) -> VALUE { return rb_float_new(dbl) }

// MARK: - Useful VALUE constants and macros

public let Qfalse: VALUE = VALUE(RUBY_Qfalse.rawValue)
public let Qtrue: VALUE = VALUE(RUBY_Qtrue.rawValue)
public let Qnil: VALUE = VALUE(RUBY_Qnil.rawValue)
public let Qundef: VALUE = VALUE(RUBY_Qundef.rawValue)

/// Is a `VALUE` truthy?
public func RB_TEST(_ v: VALUE) -> Bool {
    return !((v & VALUE(~Qnil)) == 0)
}

/// Is a `VALUE` equal to `nil`?  You probably want `!RB_TEST()` instead.
public func RB_NIL_P(_ v: VALUE) -> Bool {
    return !(v != Qnil)
}

// Not sure this one is useful
public func CLASS_OF(_ v: VALUE) -> VALUE {
    return rb_class_of(v)
}

// MARK: - String utilities

// Suddenly we're passing values by reference + using CamelCase names!

/// Do a `#to_s` on some object.  Can raise if not possible.
public func StringValue(_ v: VALUE) -> VALUE {
    return tml_ruby_StringValue(v)
}

/// Call `StringValue` and then give pointer to raw string buffer.
public func StringValuePtr(_ v: VALUE) -> UnsafePointer<UInt8>! {
    return tml_ruby_StringValuePtr(v)
}

/// Call `StringValue`, check string buffer has no NULs and return it.  Raises on error.
public func StringValueCStr(_ v: VALUE) -> UnsafePointer<Int8>! {
    return tml_ruby_StringValueCStr(v)
}

/// Number of ??bytes?? ??chars?? in the string
public func RSTRING_LEN(_ str: VALUE) -> Int {
    return tml_ruby_RSTRING_LEN(str)
}

// XXX much research to do re. encodings etc.

// MARK: - More enum-y `VALUE` type enum

// make this an actual enum?
public let T_NONE: Int32 = Int32(RUBY_T_NONE.rawValue)
public let T_NIL: Int32 = Int32(RUBY_T_NIL.rawValue)
public let T_OBJECT: Int32 = Int32(RUBY_T_OBJECT.rawValue)
public let T_CLASS: Int32 = Int32(RUBY_T_CLASS.rawValue)
public let T_ICLASS: Int32 = Int32(RUBY_T_ICLASS.rawValue)
public let T_MODULE: Int32 = Int32(RUBY_T_MODULE.rawValue)
public let T_FLOAT: Int32 = Int32(RUBY_T_FLOAT.rawValue)
public let T_STRING: Int32 = Int32(RUBY_T_STRING.rawValue)
public let T_REGEXP: Int32 = Int32(RUBY_T_REGEXP.rawValue)
public let T_ARRAY: Int32 = Int32(RUBY_T_ARRAY.rawValue)
public let T_HASH: Int32 = Int32(RUBY_T_HASH.rawValue)
public let T_STRUCT: Int32 = Int32(RUBY_T_STRUCT.rawValue)
public let T_BIGNUM: Int32 = Int32(RUBY_T_BIGNUM.rawValue)
public let T_FILE: Int32 = Int32(RUBY_T_FILE.rawValue)
public let T_FIXNUM: Int32 = Int32(RUBY_T_FIXNUM.rawValue)
public let T_TRUE: Int32 = Int32(RUBY_T_TRUE.rawValue)
public let T_FALSE: Int32 = Int32(RUBY_T_FALSE.rawValue)
public let T_DATA: Int32 = Int32(RUBY_T_DATA.rawValue)
public let T_MATCH: Int32 = Int32(RUBY_T_MATCH.rawValue)
public let T_SYMBOL: Int32 = Int32(RUBY_T_SYMBOL.rawValue)
public let T_RATIONAL: Int32 = Int32(RUBY_T_RATIONAL.rawValue)
public let T_COMPLEX: Int32 = Int32(RUBY_T_COMPLEX.rawValue)
public let T_IMEMO: Int32 = Int32(RUBY_T_IMEMO.rawValue)
public let T_UNDEF: Int32 = Int32(RUBY_T_UNDEF.rawValue)
public let T_NODE: Int32 = Int32(RUBY_T_NODE.rawValue)
public let T_ZOMBIE: Int32 = Int32(RUBY_T_ZOMBIE.rawValue)
public let T_MASK: Int32 = Int32(RUBY_T_MASK.rawValue)

//#define TYPE(x) rb_type((VALUE)(x)) -> enum?

// MARK: - Testing whether a `VALUE` is of a particular type

public func RB_FIXNUM_P(_ f: VALUE) -> Bool {
    return (f & VALUE(RUBY_FIXNUM_FLAG.rawValue)) != 0
}

public func RB_IMMEDIATE_P(_ x: VALUE) -> Bool {
    return (x & VALUE(RUBY_IMMEDIATE_MASK.rawValue)) != 0
}

public func RB_STATIC_SYM_P(_ x: VALUE) -> Bool {
    //#define RB_STATIC_SYM_P(x) (((VALUE)(x)&~((~(VALUE)0)<<RUBY_SPECIAL_SHIFT)) == RUBY_SYMBOL_FLAG)
    return (x & ((1<<RUBY_SPECIAL_SHIFT.rawValue)-1)) == RUBY_SYMBOL_FLAG.rawValue
}

public func RB_DYNAMIC_SYM_P(_ x: VALUE) -> Bool {
    return !RB_SPECIAL_CONST_P(x) && RB_BUILTIN_TYPE(x) == RUBY_T_SYMBOL.rawValue
}

public func RB_SYMBOL_P(_ x: VALUE) -> Bool {
    return RB_STATIC_SYM_P(x) || RB_DYNAMIC_SYM_P(x)
}

public func RB_FLONUM_P(_ x: VALUE) -> Bool {
    return (x & VALUE(RUBY_FLONUM_MASK.rawValue)) == RUBY_FLONUM_FLAG.rawValue
}

public func RB_FLOAT_TYPE_P(_ obj: VALUE) -> Bool {
    return RB_FLONUM_P(obj) ||
        (!RB_SPECIAL_CONST_P(obj) && RB_BUILTIN_TYPE(obj) == RUBY_T_FLOAT.rawValue)
}

public func RB_SPECIAL_CONST_P(_ x: VALUE) -> Bool {
    return RB_IMMEDIATE_P(x) || !RB_TEST(x)
}

public func RB_BUILTIN_TYPE(_ x: VALUE) -> Int32 {
    return tml_ruby_rb_builtin_type(x)
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

//#define RB_OBJ_WB_UNPROTECT(x)      rb_obj_wb_unprotect(x, __FILE__, __LINE__)
//#define RB_OBJ_WRITE(a, slot, b)       rb_obj_write((VALUE)(a), (VALUE *)(slot),(VALUE)(b), __FILE__, __LINE__)

// MARK: - Not sure if we will need these

public func RB_ID2SYM(_ x: ID) -> VALUE {
    return rb_id2sym(x)
}

public func RB_SYM2ID(_ x: VALUE) -> ID {
    return rb_sym2id(x)
}

// MARK: - Low-level FIXNUM manipulation

// Probably don't need these any more.

/// The signed-integer type of the same width as `VALUE`
public typealias SIGNED_VALUE = Int

public let RUBY_FIXNUM_MAX = SIGNED_VALUE.max >> 1
public let RUBY_FIXNUM_MIN = SIGNED_VALUE.min >> 1

public func RB_LONG2FIX(_ i: Int) -> VALUE {
    return (VALUE(bitPattern: i) << 1) | VALUE(RUBY_FIXNUM_FLAG.rawValue)
}

public func RB_FIX2LONG(_ v: VALUE) -> Int {
    return rb_fix2long(v)
}

public func RB_FIX2ULONG(_ v: VALUE) -> UInt {
    return rb_fix2ulong(v)
}

public func RB_POSFIXABLE(_ f: SIGNED_VALUE) -> Bool {
    return f < RUBY_FIXNUM_MAX + 1
}

public func RB_NEGFIXABLE(_ f: SIGNED_VALUE) -> Bool {
    return f >= RUBY_FIXNUM_MIN
}

public func RB_FIXABLE(_ f: SIGNED_VALUE) -> Bool {
    return RB_POSFIXABLE(f) && RB_NEGFIXABLE(f)
}
