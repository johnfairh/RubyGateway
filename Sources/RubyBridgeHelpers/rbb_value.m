//
//  rbb_value.m
//  RubyBridgeHelpers
//
//  Distributed under the MIT license, see LICENSE
//

@import CRuby;
#import "rbb_helpers.h"

//
// # VALUE protection.
//
// Ruby GC relies on being able to find VALUEs that are in use.
// Most of the C world relies on these being on the stack, which Ruby snoops.
// Approach here to is to store each VALUE in a known-address box associated
// with each Swift `RbObject`.  Then Ruby APIs are used to register this special
// address with the GC, tied to the lifetime of the `RbObject`.
//
// The Ruby `rb_gc_register_address` APIs are not super-scalable (SLL) but should
// be OK for our use cases.  If it turns out to be too slow then we will need to
// implement a single parent Ruby object registered with GC and treat all of the
// `RbObject`s as efficiently stored dynamic children, participating in the GC
// protocols as required.  Sounds fun, might do that anyway!
//

Rbb_value * _Nonnull rbb_value_alloc(VALUE value)
{
    Rbb_value *box = malloc(sizeof(*box));
    if (box == NULL)
    {
        // No good way out here, don't want to make the RbEnv
        // initializers failable.
        abort();
    }
    box->value = value;

    // Subtlety - it would do no harm to register constants except that
    // in the scenario where Ruby is not functioning we use Qnil etc. instead
    // of actual values to avoid crashing, and we mustn't talk to the GC...
    if (!RB_SPECIAL_CONST_P(value))
    {
        rb_gc_register_address(&box->value);
    }
    return box;
}

Rbb_value *rbb_value_dup(const Rbb_value * _Nonnull box)
{
    return rbb_value_alloc(box->value);
}

void rbb_value_free(Rbb_value * _Nonnull box)
{
    if (!RB_SPECIAL_CONST_P(box->value))
    {
        rb_gc_unregister_address(&box->value);
    }
    box->value = Qundef;
    free(box);
}
