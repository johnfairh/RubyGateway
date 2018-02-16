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
// Mostly to do with numeric types, stuffing into and out of FIXNUM format.
// Punt to C to get the actual platform macro for stuff dependent on integer widths
// and build configs (FLONUM/BIGNUM).
//

//
// Swift/Ruby integer terminology.  Roughly.
//
// Ruby.VALUE == Swift.UInt
// Ruby.SIGNED_VALUE == Swift.Int
// Ruby.LONG == Swift.Int
// Ruby.INT  == Swift.Int32
// Ruby.LONG_LONG = Swift.Int64
// Ruby.SHORT = Swift.Int16
// Ruby.<stuff that is enums like special_consts> = Swift.UInt32
// RUBY.DOUBLE = Swift.Double
//

// Tests
// Do all the NUM stuff, write round-trip tests for that
// Delete routines we don't need (encoding FIXNUM basically)

public typealias SIGNED_VALUE = Int

public let RUBY_FIXNUM_MAX = SIGNED_VALUE.max >> 1
public let RUBY_FIXNUM_MIN = SIGNED_VALUE.min >> 1 // hmm

public func RB_INT2FIX(_ i: Int32) -> VALUE {
    return (VALUE(i) << 1) | VALUE(RUBY_FIXNUM_FLAG.rawValue)
}
public func RB_LONG2FIX(_ i: Int) -> VALUE {
    return (VALUE(bitPattern: i) << 1) | VALUE(RUBY_FIXNUM_FLAG.rawValue)
}

//#if SIZEOF_INT < SIZEOF_LONG
//#define rb_long2int(n) rb_long2int_inline(n)
//#else
//#define rb_long2int(n) ((int)(n))
//#endif

public func RB_FIX2LONG(_ v: VALUE) -> Int {
    return rb_fix2long(v)
}

public func RB_FIX2ULONG(_ v: VALUE) -> UInt {
    return rb_fix2ulong(v)
}

public func RB_FIXNUM_P(_ f: VALUE) -> Bool {
    return (f & VALUE(RUBY_FIXNUM_FLAG.rawValue)) != 0
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

public func RB_ID2SYM(_ x: ID) -> VALUE {
    return rb_id2sym(x)
}

public func RB_SYM2ID(_ x: VALUE) -> ID {
    return rb_sym2id(x)
}

//#if USE_FLONUM
//#define RB_FLONUM_P(x) ((((int)(SIGNED_VALUE)(x))&RUBY_FLONUM_MASK) == RUBY_FLONUM_FLAG)
//#else
//#define RB_FLONUM_P(x) 0
//#endif

public let Qfalse: VALUE = VALUE(RUBY_Qfalse.rawValue)
public let Qtrue: VALUE = VALUE(RUBY_Qtrue.rawValue)
public let Qnil: VALUE = VALUE(RUBY_Qnil.rawValue)
public let Qundef: VALUE = VALUE(RUBY_Qundef.rawValue)

public func RB_TEST(_ v: VALUE) -> Bool {
    return !((v & VALUE(~Qnil)) == 0)
}

public func RB_NIL_P(_ v: VALUE) -> Bool {
    return !(v != Qnil)
}

public func CLASS_OF(_ v: VALUE) -> VALUE {
    return rb_class_of(v)
}

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

public func RB_BUILTIN_TYPE(_ x: VALUE) -> Int32 {
    return tml_ruby_rb_builtin_type(x)
}

//#define TYPE(x) rb_type((VALUE)(x)) -> enum?
//
//#define RB_FLOAT_TYPE_P(obj) (\
//  RB_FLONUM_P(obj) || \
//  (!RB_SPECIAL_CONST_P(obj) && RB_BUILTIN_TYPE(obj) == RUBY_T_FLOAT))
//
//#define RB_TYPE_P(obj, type) ( \
//((type) == RUBY_T_FIXNUM) ? RB_FIXNUM_P(obj) : \
//((type) == RUBY_T_TRUE) ? ((obj) == RUBY_Qtrue) : \
//((type) == RUBY_T_FALSE) ? ((obj) == RUBY_Qfalse) : \
//((type) == RUBY_T_NIL) ? ((obj) == RUBY_Qnil) : \
//((type) == RUBY_T_UNDEF) ? ((obj) == RUBY_Qundef) : \
//((type) == RUBY_T_SYMBOL) ? RB_SYMBOL_P(obj) : \
//((type) == RUBY_T_FLOAT) ? RB_FLOAT_TYPE_P(obj) : \
//(!RB_SPECIAL_CONST_P(obj) && RB_BUILTIN_TYPE(obj) == (type)))


// Suddenly we're passing values by reference for no clear reason...
//#define StringValue(v) rb_string_value(&(v))
//#define StringValuePtr(v) rb_string_value_ptr(&(v))
//#define StringValueCStr(v) rb_string_value_cstr(&(v))

//#define RB_NUM2LONG(x) rb_num2long_inline(x)
//#define RB_NUM2ULONG(x) rb_num2ulong_inline(x)
//
//These 4 to C for long/int shenanigans
//#define RB_NUM2INT(x) ((int)RB_NUM2LONG(x))
//#define RB_NUM2UINT(x) ((unsigned int)RB_NUM2ULONG(x))
//#define RB_FIX2INT(x) ((int)RB_FIX2LONG(x))
//#define RB_FIX2UINT(x) ((unsigned int)RB_FIX2ULONG(x))

//#define RB_FIX2SHORT(x) (rb_fix2short((VALUE)(x)))
//#define RB_NUM2SHORT(x) rb_num2short_inline(x)
//#define RB_NUM2USHORT(x) rb_num2ushort(x)
//# define RB_NUM2LL(x) rb_num2ll_inline(x)
//# define RB_NUM2ULL(x) rb_num2ull(x)
//
//#define NUM2DBL(x) rb_num2dbl((VALUE)(x))
//#define RFLOAT_VALUE(v) rb_float_value(v)
//#define DBL2NUM(dbl)  rb_float_new(dbl)

// very selective of RSTRING..
//#define RSTRING_LEN(str) \
// (!(RBASIC(str)->flags & RSTRING_NOEMBED) ? \
// RSTRING_EMBED_LEN(str) : \
// RSTRING(str)->as.heap.len)

public func RB_SPECIAL_CONST_P(_ x: VALUE) -> Bool {
    return RB_IMMEDIATE_P(x) || !RB_TEST(x)
}

//#define RB_OBJ_WB_UNPROTECT(x)      rb_obj_wb_unprotect(x, __FILE__, __LINE__)
//#define RB_OBJ_WRITE(a, slot, b)       rb_obj_write((VALUE)(a), (VALUE *)(slot),(VALUE)(b), __FILE__, __LINE__)

// go C
//#if SIZEOF_INT < SIZEOF_LONG
//# define RB_INT2NUM(v) RB_INT2FIX((int)(v))
//# define RB_UINT2NUM(v) RB_LONG2FIX((unsigned int)(v))
//#else

//#define RB_LONG2NUM(x) rb_long2num_inline(x)
//#define RB_ULONG2NUM(x) rb_ulong2num_inline(x)
//#define RB_NUM2CHR(x) rb_num2char_inline(x)
//#define RB_CHR2FIX(x) RB_INT2FIX((long)((x)&0xff))

// go C, wtf is ST? short?
//#define RB_ST2FIX(h) RB_LONG2FIX((long)(h))
