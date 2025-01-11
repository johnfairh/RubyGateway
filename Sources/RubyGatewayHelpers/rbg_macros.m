//
//  rbg_macros.m
//  RubyGatewayHelpers
//
//  Distributed under the MIT license, see LICENSE
//

@import CRuby;
#import "rbg_helpers.h"

// The RSTRING routines accesss the underlying structures
// that have too many unions for Swift to access safely.
//
// And they go from macros to inlines in Ruby 3 which the
// Swift importer sort-of imports.
long rbg_RSTRING_LEN(VALUE v)
{
    return RSTRING_LEN(v);
}

const char *rbg_RSTRING_PTR(VALUE v)
{
    return RSTRING_PTR(v);
}

// # Version constants
// These are exported as char [] which don't get imported
const char *rbg_ruby_version(void)
{
    return ruby_version;
}

const char *rbg_ruby_description(void)
{
    return ruby_description;
}

// This is '-1' cast to pfn...
rb_unblock_function_t * _Nonnull rbg_RUBY_UBF_IO(void)
{
    return RUBY_UBF_IO;
}

// Ruby pre-3 and 3+

// Ruby 3 adds actual C enums for ruby_value_type and ruby_special_constants.
// These import into Swift as different types so we collapse here.
int rbg_type(VALUE v) { return rb_type(v); }
int rbg_qfalse(void) { return RUBY_Qfalse; }
int rbg_qtrue(void) { return RUBY_Qtrue; }
int rbg_qnil(void)  { return RUBY_Qnil; }
int rbg_qundef(void) { return RUBY_Qundef; }

// These become inlines in Ruby 3 that get imported
int rbg_RB_TEST(VALUE v) { return RB_TEST(v); }
int rbg_RB_NIL_P(VALUE v) { return RB_NIL_P(v); }

// See comment on call in RbVM.swift
void rbg_RUBY_INIT_STACK(void) {
    RUBY_INIT_STACK;
}
