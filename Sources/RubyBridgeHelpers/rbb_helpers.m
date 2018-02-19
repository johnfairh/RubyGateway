//
//  TMLRubyHelpers.m
//  TMLRuby
//
//  Created by John Fairhurst on 15/02/2018.
//

@import CRuby;
#import "rbb_helpers.h"

//
// # Thunks for Exception Handling
//
// If there is an unhandled exception then Ruby crashes the process.
// We elect to never let this occur via TMLRuby APIs.
//
// The way to handle an exception in the C API is to wrap the throwy
// call in `rb_protect()`.
//
// (`rb_rescue()` does not handle all exceptions and the varargs `rb_rescue2()`
// doesn't make it through the clang importer so we'd need this kind of code
// anyway.)
//
//
// The normal flow goes:
//
//   client_1 -> rb_protect              // call from client code
//
//         client_2 <- rb_protect        // call from Ruby to client-provided throwy code
//
//            client_2 -> rb_something   // throwy call
//
//            client_2 <- rb_something   // unwind
//
//         client_2 -> rb_protect        // unwind
//
//   client_1 <- rb_protect              // unwind
//
//
// The exception flow goes:
//
//   client_1 -> rb_protect              // call from client code, Ruby does setjmp()
//
//         client_2 <- rb_protect        // call from Ruby to client-provided throwy code
//
//            client_2 -> rb_something   // throwy call
//
//                        rb_something   // EXCEPTION - longjump()
//
//   client_1 <- rb_protect              // unwind
//
// So, the key difference is that the bottom part of `client_2` and its return
// to rb_protect is skipped.
//
// Swift does not handle this: it assumes all functions will run to completion,
// or the process will exit.
//
// So we cannot implement `client_2` in Swift.  This file contains the implementations
// of `client_2` in regular C that is totally happy to be longjmp()d over.
//

static VALUE rbb_require_thunk(VALUE value)
{
    const char *fname = (const char *)(void *)value;
    return rb_require(fname);
}

VALUE rbb_require_protect(const char *fname, int *status)
{
    return rb_protect(rbb_require_thunk, (VALUE)(void *)fname, status);
}

//
// # Difficult Macros
//
// Some of the ruby.h API is too groady for the Swift Clang Importer to
// tolerate, usually because the C has difficult typecasts in it but sometimes
// for no obvious reason.
// 
// Some of these APIs are pretty useful so we reimplement them here providing
// a wrapper that looks type-safe for Swift to call.
//

int rbb_RB_BUILTIN_TYPE(VALUE value)
{
    return RB_BUILTIN_TYPE(value);
}

//
// # Numeric conversions
//

int          rbb_RB_NUM2INT(VALUE x)         { return RB_NUM2INT(x); }
unsigned int rbb_RB_NUM2UINT(VALUE x)        { return RB_NUM2UINT(x); }
VALUE        rbb_RB_INT2NUM(int v)           { return RB_INT2NUM(v); }
VALUE        rbb_RB_UINT2NUM(unsigned int v) { return RB_UINT2NUM(v); }

//
// # String methods
//
// The StringValue routines are quite subtle because of the `to_s` issue,
// they potentially create a new T_STRING that replaces the passed-in
// VALUE.
//
// TODO: Take out/rephrase these?

VALUE rbb_StringValue(VALUE *v)
{   // #define StringValue(v) rb_string_value(&(v))
    return rb_string_value(v);
}

const char *rbb_StringValuePtr(VALUE *v)
{   // #define StringValuePtr(v) rb_string_value_ptr(&(v))
    return rb_string_value_ptr(v);
}

const char *rbb_StringValueCStr(VALUE *v)
{   //#define StringValueCStr(v) rb_string_value_cstr(&(v))
    return rb_string_value_cstr(v);
}

// The RSTRING routines accesss the underlying structures
// that have too many unions for Swift to access safely.
long rbb_RSTRING_LEN(VALUE v)
{
    return RSTRING_LEN(v);
}

const char *rbb_RSTRING_PTR(VALUE v)
{
    return RSTRING_PTR(v);
}

//
// # Version constants
//
// These are exported as char [] which don't get imported
//

const char *rbb_ruby_version(void)
{
    return ruby_version;
}

const char *rbb_ruby_description(void)
{
    return ruby_description;
}

//
// # VALUE protection
//

Rbb_value * _Nonnull rbb_value_alloc(VALUE value)
{
    Rbb_value *box = malloc(sizeof(*box));
    if (box == NULL) {
        /* No good way out here, don't want to make the RbEnv
           initializers failable.
         */
        abort();
    }
    box->value = value;
    rb_gc_register_address(&box->value);
    return box;
}

Rbb_value *rbb_value_dup(const Rbb_value * _Nonnull box)
{
    return rbb_value_alloc(box->value);
}

void rbb_value_free(Rbb_value * _Nonnull box)
{
    rb_gc_unregister_address(&box->value);
    box->value = Qundef;
    free(box);
}
