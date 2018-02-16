//
//  CRubyMacros.swift
//  TMLRuby
//
//  Created by John Fairhurst on 15/02/2018.
//

import CRuby
import TMLRubyHelpers

// Various useful stuff from ruby.h that didn't make it through the clang importer.

public typealias SIGNED_VALUE = Int

//public func RB_FIXNUM_P(_ f: VALUE) -> Bool {
//    return (((SIGNED_VALUE(f) & RUBY_FIXNUM_FLAG.rawValue) != 0
//}

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

public func RB_BUILTIN_TYPE(_ x: VALUE) -> Int32 {
    return tml_ruby_rb_builtin_type(x)
}

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

//public func TYPE(_ obj: VALUE) -> Int32 {
//    if (RB_IMMEDIATE_P(obj)) {
//        if (RB_FIXNUM_P(obj)) return T_FIXNUM;
//        if (RB_FLONUM_P(obj)) return T_FLOAT;
//        if (obj == Qtrue)  return T_TRUE;
//        if (RB_STATIC_SYM_P(obj)) return T_SYMBOL;
//        if (obj == Qundef) return T_UNDEF;
//    }
//    else if (!RB_TEST(obj)) {
//        if (obj == Qnil)   { return T_NIL; }
//        if (obj == Qfalse) { return T_FALSE; }
//    }
//    return RB_BUILTIN_TYPE(obj);
//}

