//
//  TMLRubyThunks.h
//  TMLRuby
//
//  Created by John Fairhurst on 15/02/2018.
//

#ifndef TMLRubyThunks_h
#define TMLRubyThunks_h

/// Safely call `rb_require` and report exception status.
VALUE tml_ruby_require_protect(const char *fname, int *status);

/// Wrap up RB_BUILTIN_TYPE for Swift
int tml_ruby_rb_builtin_type(VALUE value);

#endif /* TMLRubyThunks_h */
