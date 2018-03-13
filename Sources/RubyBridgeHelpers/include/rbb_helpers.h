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

/* Linux Clang 6 is unhappy with @import syntax when processing this
 * lib's module map as part of building the Swift module RubyBridge.
 * ???
 */
#ifdef __linux__
typedef unsigned long VALUE;
typedef VALUE ID;
#else
@import CRuby;
#endif

/// Safely call `rb_load` and report exception status.
void rbb_load_protect(VALUE fname, int wrap, int * _Nullable status);

/// Safely call `rb_intern` and report exception status.
ID rbb_intern_protect(const char * _Nonnull name, int * _Nullable status);

/// Safely call `rb_const_get_at` and report exception status.
VALUE rbb_const_get_protect(VALUE value, ID id, int * _Nullable status);

/// Safely call `rb_const_get_at` and report exception status.
VALUE rbb_const_get_at_protect(VALUE value, ID id, int * _Nullable status);

/// Safely call `rb_inspect` and report exception status.
VALUE rbb_inspect_protect(VALUE value, int * _Nullable status);

/// Safely call `rb_funcallv` and report exception status.
VALUE rbb_funcallv_protect(VALUE value, ID id,
                           int argc, const VALUE * _Nonnull argv,
                           int * _Nullable status);

typedef VALUE (*Rbb_swift_block_call)(void * _Nullable context,
                                      int argc, const VALUE * _Nonnull argv);

VALUE rbb_block_call_protect(VALUE value, ID id,
                             int argc, const VALUE * _Nonnull argv,
                             Rbb_swift_block_call _Nonnull block,
                             void * _Nullable context,
                             int * _Nullable status);

/// Safely call `rb_cvar_get` and report exception status.
VALUE rbb_cvar_get_protect(VALUE clazz, ID id, int * _Nullable status);

/// Safely call `rb_String` and report exception status.
VALUE rbb_String_protect(VALUE v, int * _Nullable status);

/// String APIs with un-Swift requirements
long                  rbb_RSTRING_LEN(VALUE v);
const char * _Nonnull rbb_RSTRING_PTR(VALUE v);

/// Safely call `rb_num2ulong(rb_Integer)` and report exception status.
/// Additionally, raise an exception if the number is negative.
unsigned long rbb_obj2ulong_protect(VALUE v, int * _Nullable status);

/// Safely call `rb_num2long(rb_Integer)` and report exception status.
long rbb_obj2long_protect(VALUE v, int * _Nullable status);

/// Safely call `rb_num2dbl(rb_Float)` and report exception status.
double rbb_obj2double_protect(VALUE v, int * _Nullable status);

/// Strings hidden from importer
const char * _Nonnull rbb_ruby_version(void);
const char * _Nonnull rbb_ruby_description(void);

/// Cross Ruby version support
unsigned long rbb_fix2ulong(VALUE v);
long          rbb_fix2long(VALUE v);

/// Rbb_value - keep a VALUE safe so it does not get GC'ed
typedef struct  {
    VALUE value;
} Rbb_value;

Rbb_value * _Nonnull rbb_value_alloc(VALUE value);
Rbb_value * _Nonnull rbb_value_dup(const Rbb_value * _Nonnull box);
void                 rbb_value_free(Rbb_value * _Nonnull box);

#endif /* rbb_helpers_h */
