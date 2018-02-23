//
//  rbb_helpers.h
//  RubyBridgeHelpers
//
//  Distributed under the MIT license, see LICENSE
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

/// Safely call `rb_intern` and report exception status.
ID rbb_intern_protect(const char * _Nonnull name, int * _Nullable status);

/// Safely call `rb_const_get_at` and report exception status.
VALUE rbb_const_get_protect(VALUE value, ID id, int * _Nullable status);

/// Safely call `rb_const_get_at` and report exception status.
VALUE rbb_const_get_at_protect(VALUE value, ID id, int * _Nullable status);

/// Wrap up RB_BUILTIN_TYPE for Swift
int rbb_RB_BUILTIN_TYPE(VALUE value);

/// Safely call `rb_String` and report exception status.
VALUE rbb_String_protect(VALUE v, int * _Nullable status);

/// String APIs with un-Swift requirements
long                  rbb_RSTRING_LEN(VALUE v);
const char * _Nonnull rbb_RSTRING_PTR(VALUE v);

/// Safely call `rbb_num2ulong` and report exception status.
/// Additionally, raise an exception if the number is negative.
unsigned long rbb_num2ulong_protect(VALUE v, int * _Nullable status);

/// Safely call `rbb_num2long` and report exception status.
long rbb_num2long_protect(VALUE v, int * _Nullable status);

/// Safely call `rbb_num2double` and report exception status.
double rbb_num2double_protect(VALUE v, int * _Nullable status);

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
