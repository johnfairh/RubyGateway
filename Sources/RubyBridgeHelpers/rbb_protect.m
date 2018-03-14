//
//  rbb_helpers.m
//  RubyBridgeHelpers
//
//  Distributed under the MIT license, see LICENSE
//

@import CRuby;
#import "rbb_helpers.h"
#import <stdbool.h>
#import <stdint.h>

// Fixups for Ruby < 2.3

#ifndef RB_NUM2LONG
#define RB_NUM2LONG NUM2LONG
#endif

#ifndef RB_FIX2LONG
#define RB_FIX2LONG FIX2LONG
#endif

#ifndef RB_FIX2ULONG
#define RB_FIX2ULONG FIX2ULONG
#endif

#ifndef RUBY_FL_USER1
#define RUBY_FL_USER1 FL_USER1
#endif

//
// # Thunks for Exception Handling
//
// If there is an unhandled exception then Ruby crashes the process.
// We elect to never let this occur via RubyBridge APIs.
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

// Just use a single type with a cookie to pass params down the stack.
// I had a lovely version using blocks but then tried to build it on Linux ;-(

typedef enum {
    RBB_JOB_LOAD,
    RBB_JOB_INTERN,
    RBB_JOB_CONST_GET,
    RBB_JOB_CONST_GET_AT,
    RBB_JOB_FUNCALLV,
    RBB_JOB_BLOCK_CALL,
    RBB_JOB_CVAR_GET,
    RBB_JOB_TO_ULONG,
    RBB_JOB_TO_LONG,
    RBB_JOB_TO_DOUBLE,
    RBB_JOB_PROC_NEW,
    RBB_JOB_PROC_CALL,
} Rbb_job;

typedef struct {
    Rbb_job       job;

    VALUE         value;
    ID            id;

    bool          loadWrap;
    const char   *internName;
    int           argc;
    const VALUE  *argv;
    double        toDoubleResult;
    Rbb_swift_block_call block;
    void                *blockContext;
    VALUE                blockArg;
} Rbb_protect_data;

#define RBB_PDATA_TO_VALUE(pdata) ((uintptr_t)(void *)(pdata))
#define RBB_VALUE_TO_PDATA(value) ((Rbb_protect_data *)(void *)(uintptr_t)(value))

static VALUE rbb_obj2ulong(VALUE v);

/// Callback made by Ruby from `rb_protect` -- OK to raise exceptions from here.
static VALUE rbb_protect_thunk(VALUE value)
{
    Rbb_protect_data *d = RBB_VALUE_TO_PDATA(value);
    VALUE rc = Qundef;

    switch (d->job)
    {
    case RBB_JOB_LOAD:
        rb_load(d->value, d->loadWrap);
        break;
    case RBB_JOB_INTERN:
        rc = (VALUE) rb_intern(d->internName);
        break;
    case RBB_JOB_CONST_GET:
        rc = rb_const_get(d->value, d->id);
        break;
    case RBB_JOB_CONST_GET_AT:
        rc = rb_const_get_at(d->value, d->id);
        break;
    case RBB_JOB_FUNCALLV:
        rc = rb_funcallv(d->value, d->id, d->argc, d->argv);
        break;
    case RBB_JOB_BLOCK_CALL:
        rc = rb_block_call(d->value, d->id, d->argc, d->argv, d->block, (VALUE) d->blockContext);
        break;
    case RBB_JOB_CVAR_GET:
        rc = rb_cvar_get(d->value, d->id);
        break;
    case RBB_JOB_TO_ULONG:
        rc = rbb_obj2ulong(d->value);
        break;
    case RBB_JOB_TO_LONG:
        rc = (VALUE) RB_NUM2LONG(rb_Integer(d->value));
        break;
    case RBB_JOB_TO_DOUBLE:
        d->toDoubleResult = NUM2DBL(rb_Float(d->value));
        break;
    case RBB_JOB_PROC_NEW:
        rc = rb_proc_new(d->block, (VALUE) d->blockContext);
        break;
    case RBB_JOB_PROC_CALL:
        rc = rb_proc_call_with_block(d->value, d->argc, d->argv, d->blockArg);
        break;
    }
    return rc;
}

/// Run the job described by `data` and report exception status in `status`.
static VALUE rbb_protect(Rbb_protect_data * _Nonnull data, int * _Nullable status)
{
    return rb_protect(rbb_protect_thunk, RBB_PDATA_TO_VALUE(data), status);
}

// rb_load -- rb_load_protect exists but doesn't protect against exceptions
// raised by the file being loaded, just the filename lookup part.
void rbb_load_protect(VALUE fname, int wrap, int * _Nullable status)
{
    Rbb_protect_data data = { .job = RBB_JOB_LOAD, .value = fname, .loadWrap = wrap };

    // rb_load_protect has another bug, if you send it null status
    // then it accesses the pointer anyway.  Recent regression, will try to fix...
    int tmpStatus = 0;
    if (status == NULL)
    {
        status = &tmpStatus;
    }

    (void) rbb_protect(&data, status);
}

// rb_intern - can technically run out of IDs....
ID rbb_intern_protect(const char * _Nonnull name, int * _Nullable status)
{
    Rbb_protect_data data = { .job = RBB_JOB_INTERN, .internName = name };
    return (ID) rbb_protect(&data, status);
}

// rb_const_get - raises if not found
VALUE rbb_const_get_protect(VALUE value, ID id, int * _Nullable status)
{
    Rbb_protect_data data = { .job = RBB_JOB_CONST_GET, .value = value, .id = id };
    return rbb_protect(&data, status);
}

// rb_const_get_at - raises if not found
VALUE rbb_const_get_at_protect(VALUE value, ID id, int * _Nullable status)
{
    Rbb_protect_data data = { .job = RBB_JOB_CONST_GET_AT, .value = value, .id = id };
    return rbb_protect(&data, status);
}

// rb_inspect - raises if can't get a string out
VALUE rbb_inspect_protect(VALUE value, int * _Nullable status)
{
    return rb_protect(rb_inspect, value, status);
}

// rb_funcallv - run arbitrary code
VALUE rbb_funcallv_protect(VALUE value, ID id,
                           int argc, const VALUE * _Nonnull argv,
                           int * _Nullable status)
{
    Rbb_protect_data data = { .job = RBB_JOB_FUNCALLV, .value = value, .id = id,
                              .argc = argc, .argv = argv };
    return rbb_protect(&data, status);
}

// rb_block_call - run arbitrary code twice
VALUE rbb_block_call_protect(VALUE value, ID id,
                             int argc, const VALUE * _Nonnull argv,
                             Rbb_swift_block_call _Nonnull block,
                             void * _Nonnull context,
                             int * _Nullable status)
{
    Rbb_protect_data data = { .job = RBB_JOB_BLOCK_CALL, .value = value, .id = id,
                              .argc = argc, .argv = argv,
                              .block = block, .blockContext = context };
    return rbb_protect(&data, status);
}

// rb_cvar_get - raises if you look at it funny
VALUE rbb_cvar_get_protect(VALUE clazz, ID id, int * _Nullable status)
{
    Rbb_protect_data data = { .job = RBB_JOB_CVAR_GET, .value = clazz, .id = id };
    return rbb_protect(&data, status);
}

// rb_String - raises if it can't get a string out.
VALUE rbb_String_protect(VALUE v, int * _Nullable status)
{
    return rb_protect(rb_String, v, status);
}

//
// Integer numeric conversion
//
// Ruby allows implicit signed -> unsigned conversion which is too
// slapdash for the Swift interface.  This seems to be remarkably
// baked into Ruby's numerics, so we do some 'orrible rooting around
// to figure it out.
//

static int rbb_numeric_ish_type(VALUE v)
{
    return NIL_P(v) ||
           FIXNUM_P(v) ||
           RB_TYPE_P(v, T_FLOAT) ||
           RB_TYPE_P(v, T_BIGNUM);
}

static VALUE rbb_obj2ulong(VALUE v)
{
    // Drill down to find something we can actually compare to zero.
    while (!rbb_numeric_ish_type(v))
    {
        v = rb_Integer(v);
    }

    // Now decide if this looks negative
    bool negative = false;

    if (FIXNUM_P(v))
    {
        negative = (RB_FIX2LONG(v) < 0);
    }
    else if (RB_TYPE_P(v, T_FLOAT))
    {
        negative = (NUM2DBL(v) < 0);
    }
    else if (RB_TYPE_P(v, T_BIGNUM))
    {   // don't @ me
        negative = ((RBASIC(v)->flags & RUBY_FL_USER1) == 0);
    }

    if (negative)
    {
        rb_raise(rb_eTypeError, "Value is negative and cannot be expressed as unsigned.");
    }

    return rb_num2ulong(v);
}

// rb_obj2ulong - raises if can't do conversion
unsigned long rbb_obj2ulong_protect(VALUE v, int * _Nullable status)
{
    Rbb_protect_data data = { .job = RBB_JOB_TO_ULONG, .value = v };
    return rbb_protect(&data, status);
}

// rb_num2long etc. - raises if can't do conversion
long rbb_obj2long_protect(VALUE v, int * _Nullable status)
{
    Rbb_protect_data data = { .job = RBB_JOB_TO_LONG, .value = v };
    return rbb_protect(&data, status);
}

// rb_Float - raises if can't do conversion.
double rbb_obj2double_protect(VALUE v, int * _Nullable status)
{
    Rbb_protect_data data = { .job = RBB_JOB_TO_DOUBLE, .value = v };
    rbb_protect(&data, status);
    return data.toDoubleResult;
}

// rb_proc_new - raises in various conditions.
VALUE rbb_proc_new_protect(Rbb_swift_block_call _Nonnull block,
                           void * _Nonnull context,
                           int * _Nullable status)
{
    Rbb_protect_data data = { .job = RBB_JOB_PROC_NEW, .block = block, .blockContext = context };
    return rbb_protect(&data, status);
}

// rb_proc_call - arbitrary code
VALUE rbb_proc_call_with_block_protect(VALUE value,
                                       int argc, const VALUE * _Nonnull argv,
                                       VALUE blockArg,
                                       int * _Nullable status)
{
    Rbb_protect_data data = { .job = RBB_JOB_PROC_CALL, .value = value,
        .argc = argc, .argv = argv, .blockArg = blockArg };
    return rbb_protect(&data, status);
}
