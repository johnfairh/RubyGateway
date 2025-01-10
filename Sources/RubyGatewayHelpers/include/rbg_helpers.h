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

/// Call `RUBY_INIT_STACK`
void rbg_RUBY_INIT_STACK(void);

/// Safely call `rb_load` and report exception status.
void rbg_load_protect(VALUE fname, int wrap, int * _Nonnull status);

/// Safely call `rb_intern` and report exception status.
ID rbg_intern_protect(const char * _Nonnull name, int * _Nonnull status);

/// Safely call `rb_const_get_at` and report exception status.
VALUE rbg_const_get_protect(VALUE value, ID id, int * _Nonnull status);

/// Safely call `rb_const_get_at` and report exception status.
VALUE rbg_const_get_at_protect(VALUE value, ID id, int * _Nonnull status);

/// Safely call `rb_const_set` and report exception status.
void rbg_const_set_protect(VALUE clazz, ID id, VALUE constant,
                           int * _Nonnull status);

/// Safely call `rb_inspect` and report exception status.
VALUE rbg_inspect_protect(VALUE value, int * _Nonnull status);

/// Safely call `rb_funcallv` and report exception status.
VALUE rbg_funcallv_protect(VALUE value, ID id,
                           int argc, const VALUE * _Nonnull argv, int kwArgs,
                           int * _Nonnull status);

/// Safely call `rb_yield_values2` and report exception status.
VALUE rbg_yield_values(int argc,
                       const VALUE * _Nonnull argv, int kwArgs,
                       int * _Nonnull status);

/// Things a Swift callback can ask Ruby to do
typedef enum {
    /// Return a VALUE - normal case
    RBG_RT_VALUE,
    /// Raise an exception
    RBG_RT_RAISE,
    /// Do 'break' - rare use in iterator blocks
    RBG_RT_BREAK,
    /// Do 'break' with a value - rare use in iterator blocks
    RBG_RT_BREAK_VALUE,
    /// Continue non-local flow control (throw, return, break)
    RBG_RT_JUMP,
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
                                   int argc, const VALUE * _Nonnull argv, int kwArgs,
                                   void * _Nonnull context,
                                   int * _Nonnull status);

/// Safely call `rb_block_call`, invoking the registered value-context
/// block handler with the given context as the block.
/// And report exception status.
VALUE rbg_block_call_value_protect(VALUE value, ID id,
                                   int argc, const VALUE * _Nonnull argv, int kwArgs,
                                   VALUE context,
                                   int * _Nonnull status);

/// Safely call `rb_proc_call_with_block` and report exception status.
VALUE rbg_proc_call_with_block_protect(VALUE value,
                                       int argc, const VALUE * _Nonnull argv,
                                       VALUE blockArg,
                                       int * _Nonnull status);

/// Safely call `rb_cvar_get` and report exception status.
VALUE rbg_cvar_get_protect(VALUE clazz, ID id, int * _Nonnull status);

/// Safely call `rb_String` and report exception status.
VALUE rbg_String_protect(VALUE v, int * _Nonnull status);

/// String APIs with un-Swift requirements
long                  rbg_RSTRING_LEN(VALUE v);
const char * _Nonnull rbg_RSTRING_PTR(VALUE v);

/// Safely call `rb_num2ulong(rb_Integer)` and report exception status.
/// Additionally, raise an exception if the number is negative.
unsigned long rbg_obj2ulong_protect(VALUE v, int * _Nonnull status);

/// Safely call `rb_num2long(rb_Integer)` and report exception status.
long rbg_obj2long_protect(VALUE v, int * _Nonnull status);

/// Safely call `rb_num2dbl(rb_Float)` and report exception status.
double rbg_obj2double_protect(VALUE v, int * _Nonnull status);

/// Safely call `rb_Array` and report exception status.
VALUE rbg_Array_protect(VALUE v, int * _Nonnull status);

/// Safely call `rb_Hash` (sort of) and report exception status.
VALUE rbg_Hash_protect(VALUE v, int * _Nonnull status);

/// Safely call `rb_error_arity` and report exception status.
void rbg_error_arity_protect(int argc, int min, int max, int * _Nonnull status);

/// Safely call `rb_extract/scan_args` and report exception status.
VALUE rbg_scan_arg_hash_protect(VALUE last_arg,
                                int * _Nonnull is_hash,
                                int * _Nonnull is_opts,
                                int * _Nonnull status);

/// Safely call rb_define_class[_under] and report exception status.
VALUE rbg_define_class_protect(const char * _Nonnull name,
                               VALUE underClass,
                               VALUE parentClass,
                               int * _Nonnull status);

/// Safely call rb_define_module[_under] and report exception status.
VALUE rbg_define_module_protect(const char * _Nonnull name,
                                VALUE underClass,
                                int * _Nonnull status);

typedef enum {
    RBG_INJECT_INCLUDE,
    RBG_INJECT_PREPEND,
    RBG_INJECT_EXTEND
} Rbg_inject_type;

/// Safely call rb_include/prepend/extend and report exception status.
void rbg_inject_module_protect(VALUE into, VALUE module,
                               Rbg_inject_type type,
                               int * _Nonnull status);

VALUE rbg_call_super_protect(int argc, const VALUE * _Nonnull argv, int kwArgs,
                             int * _Nonnull status);

/// Callback into Swift code for gvar access
typedef VALUE (*Rbg_gvar_get_call)(ID id);
typedef void (*Rbg_gvar_set_call)(ID id,
                                  VALUE newValue,
                                  Rbg_return_value * _Nonnull returnValue);

/// Set the single functions where all gvar calls go
void rbg_register_gvar_callbacks(Rbg_gvar_get_call _Nonnull get,
                                 Rbg_gvar_set_call _Nonnull set);

/// Bind a global variable name to Swift code
ID rbg_create_virtual_gvar(const char * _Nonnull name, int readonly);

/// Strings hidden from importer
const char * _Nonnull rbg_ruby_version(void);
const char * _Nonnull rbg_ruby_description(void);

/// Horrible casts rejected by importer
typedef void rbg_unblock_function_t(void * _Nullable);
rbg_unblock_function_t * _Nonnull rbg_RUBY_UBF_IO(void);

/// Ruby 3 incompatible changes from Swift's point of view
int rbg_type(VALUE v);
int rbg_qfalse(void);
int rbg_qtrue(void);
int rbg_qnil(void);
int rbg_qundef(void);
int rbg_RB_TEST(VALUE v);
int rbg_RB_NIL_P(VALUE v);

/// Rbg_value - keep a VALUE safe so it does not get GC'ed
typedef struct  {
    VALUE value;
} Rbg_value;

Rbg_value * _Nonnull rbg_value_alloc(VALUE value);
Rbg_value * _Nonnull rbg_value_dup(const Rbg_value * _Nonnull box);
void                 rbg_value_free(Rbg_value * _Nonnull box);

/// Method calling

/// Value used to identify a particular callback.  Ruby does not allow us
/// context here so we improvise like this instead.
typedef struct {
    /// symbol for the method name.
    VALUE method;
    /// class for a regular method, attached object for a singleton.
    VALUE target;
} Rbg_method_id;

/// Swift callback that all methods go through
typedef void (*Rbg_method_call)(VALUE,                  // symbol
                                long,                   // targetCount
                                const VALUE * _Nonnull, // targets
                                VALUE,                  // self
                                int,                    // argc
                                const VALUE * _Nonnull, // argv
                                Rbg_return_value * _Nonnull);
void rbg_register_method_callback(Rbg_method_call _Nonnull);

/// Define a global function
Rbg_method_id rbg_define_global_function(const char * _Nonnull name);
/// Define a regular method on some class
Rbg_method_id rbg_define_method(VALUE clazz, const char * _Nonnull name);
/// Define a singleton method for some object
Rbg_method_id rbg_define_singleton_method(VALUE object,
                                          const char * _Nonnull name);

/// Instance binding

/// Callback into Swift code for instance alloc/free
typedef void * _Nullable (*Rbg_bind_allocate_call)(const char * _Nonnull);
typedef void (*Rbg_bind_free_call)(const char * _Nonnull, void * _Nonnull);

/// Set the single functions where all gvar calls go
void rbg_register_object_binding_callbacks(
        Rbg_bind_allocate_call _Nonnull alloc,
        Rbg_bind_free_call _Nonnull free);

/// Have Ruby associate Swift instances with this class.
void rbg_bind_class(VALUE rubyClass);

/// Get hold of the Swift object for this instance of a bound class, or NULL
/// if something is amiss.
void * _Nullable rbg_get_bound_object(VALUE instance);

#endif /* rbg_helpers_h */
