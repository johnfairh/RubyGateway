## 0.4 plan

Swift 4.1.

Conditional conformances for array etc.

## "1.0" feeling 

Collection translation, needs 4.1
* Array, Dictionary
* Set?
* Range, Slice ?
* Helpers for efficient Ruby array/hash (set?) access

Nil literal translation in StoR direction

Concurrency
* Fix races
* Understand what the Ruby story actually is and document it

Sandboxing
* Research, worth doing anything?  Even about `exit!` ?

Fix TODOs

Build
* Linux Travis

Refactor testcases

## "Post 1.0" feeling

Datatypes
* Ruby Rational + Complex wrappers

Concurrency
* Something cleverer?

Swift services to Ruby
* Tied gvars
* Swift implementations of global functions
  * 'next' thrown from Ruby proc called from Swift
* Swift implementations of classes
* GC protocol

SAFE and sandboxing

Crashiness
* Policy or something to avoid crashes in operators
