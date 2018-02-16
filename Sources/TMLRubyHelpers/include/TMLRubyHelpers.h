//
//  TMLRubyHelpers.h
//  TMLRuby
//
//  Created by John Fairhurst on 15/02/2018.
//

#ifndef TMLRubyHelpers_h
#define TMLRubyHelpers_h

/* This small C module provides a speed-matching layer between Swift and the
 * Ruby API to hide some C-ish behaviour such as type-safety and longjmp()ing
 * from Swift.
 *
 * It would be part of the TMLRuby module directly but SPM does not approve.
 */

@import CRuby;

/// Safely call `rb_require` and report exception status.
VALUE tml_ruby_require_protect(const char *fname, int *status);

/// Wrap up RB_BUILTIN_TYPE for Swift
int tml_ruby_rb_builtin_type(VALUE value);

#endif /* TMLRubyHelpers_h */
