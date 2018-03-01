//
//  rbb_macros.m
//  RubyBridgeHelpers
//
//  Distributed under the MIT license, see LICENSE
//

@import CRuby;
#import "rbb_helpers.h"

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

// # Version constants
// These are exported as char [] which don't get imported
const char *rbb_ruby_version(void)
{
    return ruby_version;
}

const char *rbb_ruby_description(void)
{
    return ruby_description;
}
