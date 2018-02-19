//
//  TMLRubyHelpers.h
//  TMLRuby
//
//  Created by John Fairhurst on 15/02/2018.
//

#ifndef TMLRubyHelpers_h
#define TMLRubyHelpers_h

/* This small C module provides a speed-matching layer between Swift and the
 * Ruby API to hide some C-ish behaviour such as type-safety and longjmp()ing
 * from Swift.
 *
 * It would be part of the TMLRuby module directly but SPM does not approve.
 */

/* Linux clang 5 is unhappy with @import syntax when processing this
 * lib's module map.  Linux issue or Clang issue? TBD, need something more
 * modern than Ubuntu 14.04 or figure out how to install clang > 5 there.
 */
#ifdef __linux__
typedef unsigned long VALUE;
#else
@import CRuby;
#endif

/// Safely call `rb_require` and report exception status.
VALUE tml_ruby_require_protect(const char * _Nonnull fname, int * _Nullable status);

/// Wrap up RB_BUILTIN_TYPE for Swift
int tml_ruby_rb_builtin_type(VALUE value);

/// Numeric conversions dependent on integer sizes
int          tml_ruby_RB_NUM2INT(VALUE x);
unsigned int tml_ruby_RB_NUM2UINT(VALUE x);
VALUE        tml_ruby_RB_INT2NUM(int v);
VALUE        tml_ruby_RB_UINT2NUM(unsigned int v);

/// String APIs with un-Swift requirements
VALUE                 tml_ruby_StringValue(VALUE * _Nonnull v);
const char * _Nonnull tml_ruby_StringValuePtr(VALUE * _Nonnull v);
const char * _Nonnull tml_ruby_StringValueCStr(VALUE * _Nonnull v);
long                  tml_ruby_RSTRING_LEN(VALUE v);
const char * _Nonnull tml_ruby_RSTRING_PTR(VALUE v);

/// Strings hidden from importer
const char * _Nonnull tml_ruby_ruby_version(void);
const char * _Nonnull tml_ruby_ruby_description(void);

#endif /* TMLRubyHelpers_h */
