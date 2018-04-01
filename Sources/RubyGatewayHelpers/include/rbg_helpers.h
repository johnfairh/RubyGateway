//
//  rbg_helpers.h
//  RubyGatewayHelpers
//
//  Distributed under the MIT license, see LICENSE
//

#ifndef rbg_helpers_h
#define rbg_helpers_h

/* This small C module provides a speed-matching layer between Swift and the
 * Ruby API to hide some C-ish behaviour such as type-safety and longjmp()ing
 * from Swift.
 */

/* Would ideally @import CRuby here, but causes weird problems building on
 * Linux/Clang 6 and is impossible with the CocoaPods setup where this header
 * file ends up in the RubyGateway module map.  This is a bit non-portable
 * though.
 */
typedef unsigned long VALUE;
typedef VALUE ID;

/// Safely call `rb_load` and report exception status.
void rbg_load_protect(VALUE fname, int wrap, int * _Nullable status);

/// Safely call `rb_intern` and report exception status.
ID rbg_intern_protect(const char * _Nonnull name, int * _Nullable status);

/// Safely call `rb_const_get_at` and report exception status.
VALUE rbg_const_get_protect(VALUE value, ID id, int * _Nullable status);

/// Safely call `rb_const_get_at` and report exception status.
VALUE rbg_const_get_at_protect(VALUE value, ID id, int * _Nullable status);

/// Safely call `rb_inspect` and report exception status.
VALUE rbg_inspect_protect(VALUE value, int * _Nullable status);

/// Safely call `rb_funcallv` and report exception status.
VALUE rbg_funcallv_protect(VALUE value, ID id,
                           int argc, const VALUE * _Nonnull argv,
                           int * _Nullable status);

/// Things a Swift callback can ask Ruby to do
typedef enum {
    /// Return a VALUE - normal case
    RBG_RT_VALUE,
    /// Raise an exception
    RBG_RT_RAISE,
    /// Do 'break' - rare use in iterator blocks
    RBG_RT_BREAK,
    /// Do 'break' with a value - rare use in iterator blocks
    RBG_RT_BREAK_VALUE
} Rbg_return_type;

/// Express what a Swift callback wants Ruby to do
typedef struct {
    /// What Swift wants to do
    Rbg_return_type type;
    /// Value to return or exception to raise
    VALUE           value;
} Rbg_return_value;

/// Callback into Swift code for a block, using a void * context
typedef void (*Rbg_pvoid_block_call)(void * _Nonnull context,
                                     int argc,
                                     const VALUE * _Nonnull argv,
                                     VALUE blockarg,
                                     Rbg_return_value * _Nonnull returnValue);

/// Callback into Swift code for a block, using a VALUE context
typedef void (*Rbg_value_block_call)(VALUE context,
                                     int argc,
                                     const VALUE * _Nonnull argv,
                                     VALUE blockarg,
                                     Rbg_return_value * _Nonnull returnValue);

/// Set the single function where all pvoid-context block/proc calls go
void rbg_register_pvoid_block_proc_callback(Rbg_pvoid_block_call _Nonnull);

/// Set the single function where all value-context block/proc calls go
void rbg_register_value_block_proc_callback(Rbg_value_block_call _Nonnull);

/// Safely call `rb_block_call`, invoking the registered pvoid-context
/// block handler with the given context as the block.
/// And report exception status.
VALUE rbg_block_call_pvoid_protect(VALUE value, ID id,
                                   int argc, const VALUE * _Nonnull argv,
                                   void * _Nonnull context,
                                   int * _Nullable status);

/// Safely call `rb_block_call`, invoking the registered value-context
/// block handler with the given context as the block.
/// And report exception status.
VALUE rbg_block_call_value_protect(VALUE value, ID id,
                                   int argc, const VALUE * _Nonnull argv,
                                   VALUE context,
                                   int * _Nullable status);

/// Safely call `rb_proc_call_with_block` and report exception status.
VALUE rbg_proc_call_with_block_protect(VALUE value,
                                       int argc, const VALUE * _Nonnull argv,
                                       VALUE blockArg,
                                       int * _Nullable status);

/// Safely call `rb_cvar_get` and report exception status.
VALUE rbg_cvar_get_protect(VALUE clazz, ID id, int * _Nullable status);

/// Safely call `rb_String` and report exception status.
VALUE rbg_String_protect(VALUE v, int * _Nullable status);

/// String APIs with un-Swift requirements
long                  rbg_RSTRING_LEN(VALUE v);
const char * _Nonnull rbg_RSTRING_PTR(VALUE v);

/// Safely call `rb_num2ulong(rb_Integer)` and report exception status.
/// Additionally, raise an exception if the number is negative.
unsigned long rbg_obj2ulong_protect(VALUE v, int * _Nullable status);

/// Safely call `rb_num2long(rb_Integer)` and report exception status.
long rbg_obj2long_protect(VALUE v, int * _Nullable status);

/// Safely call `rb_num2dbl(rb_Float)` and report exception status.
double rbg_obj2double_protect(VALUE v, int * _Nullable status);

/// Safely call `rb_Array` and report exception status
VALUE rbg_Array_protect(VALUE v, int * _Nullable status);

/// Strings hidden from importer
const char * _Nonnull rbg_ruby_version(void);
const char * _Nonnull rbg_ruby_description(void);

/// Cross Ruby version support
unsigned long rbg_fix2ulong(VALUE v);
long          rbg_fix2long(VALUE v);

/// Rbg_value - keep a VALUE safe so it does not get GC'ed
typedef struct  {
    VALUE value;
} Rbg_value;

Rbg_value * _Nonnull rbg_value_alloc(VALUE value);
Rbg_value * _Nonnull rbg_value_dup(const Rbg_value * _Nonnull box);
void                 rbg_value_free(Rbg_value * _Nonnull box);

#endif /* rbg_helpers_h */
