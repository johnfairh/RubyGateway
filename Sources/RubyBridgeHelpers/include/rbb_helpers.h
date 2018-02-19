//
//  rbb_helpers.h
//  RubyBridgeHelpers
//
//  Created by John Fairhurst on 15/02/2018.
//

#ifndef rbb_helpers_h
#define rbb_helpers_h

/* This small C module provides a speed-matching layer between Swift and the
 * Ruby API to hide some C-ish behaviour such as type-safety and longjmp()ing
 * from Swift.
 *
 * It would be part of the RubyBridge module directly but SPM does not approve.
 */

/* Linux clang 5 is unhappy with @import syntax when processing this
 * lib's module map as part of building the Swift module RubyBridge.
 * Linux issue or Clang issue? TBD, need something more modern than Ubuntu
 * 14.04 or figure out how to install clang > 5 there.
 */
#ifdef __linux__
typedef unsigned long VALUE;
#else
@import CRuby;
#endif

/// Safely call `rb_require` and report exception status.
VALUE rbb_require_protect(const char * _Nonnull fname, int * _Nullable status);

/// Wrap up RB_BUILTIN_TYPE for Swift
int rbb_RB_BUILTIN_TYPE(VALUE value);

/// Numeric conversions dependent on integer sizes
int          rbb_RB_NUM2INT(VALUE x);
unsigned int rbb_RB_NUM2UINT(VALUE x);
VALUE        rbb_RB_INT2NUM(int v);
VALUE        rbb_RB_UINT2NUM(unsigned int v);

/// String APIs with un-Swift requirements
VALUE                 rbb_StringValue(VALUE * _Nonnull v);
const char * _Nonnull rbb_StringValuePtr(VALUE * _Nonnull v);
const char * _Nonnull rbb_StringValueCStr(VALUE * _Nonnull v);
long                  rbb_RSTRING_LEN(VALUE v);
const char * _Nonnull rbb_RSTRING_PTR(VALUE v);

/// Strings hidden from importer
const char * _Nonnull rbb_ruby_version(void);
const char * _Nonnull rbb_ruby_description(void);

/// Rbb_value - keep a VALUE safe so it does not get GC'ed
typedef struct  {
    VALUE value;
} Rbb_value;

Rbb_value * _Nonnull rbb_value_alloc(VALUE value);
Rbb_value * _Nonnull rbb_value_dup(const Rbb_value * _Nonnull box);
void                 rbb_value_free(Rbb_value * _Nonnull box);

#endif /* rbb_helpers_h */
