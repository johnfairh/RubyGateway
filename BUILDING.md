Notes on how the framework is built.  There is a certain amount of messing
around to comply with the idiosyncracies of / my lack of patience with
Swift Package Manager & Cocoapods.

## Components 

* CRuby - system modulemap and headers for libruby
* RubyGatewayHelpers - C code layer, depends on CRuby
* RubyGateway - Swift layer, depends on CRuby and RubyGatewayHelpers.

## Goals 

* Users install just one thing (RubyGateway)
  * Users do not need any weird flags or settings.
* Users get just the RubyGateway interface
* Support Xcode/Carthage, SwiftPM (because Linux), CocoaPods.

Haven't managed to meet all these goals :-)

## Xcode/Carthage

CRuby is a git submodule of RubyGateway, refer to it via Xcode options.

RubyGatewayHelpers is a static library wrapped up in a modulemap.

RubyGateway depends on CRuby and RubyGatewayHelpers as modules.

Everything is awesome.

## Swift PM 

CRuby is a formal dependency from Package.swift.  The CRuby submodule
checkout is unused.

RubyGatewayHelpers is a static lib, RubyGateway depends on them both like
the Xcode version.

Everything is fine.

## CocoaPods

CRuby is a git submodule of RubyGateway, refer to it via Xcode options.

CocoaPods seems to be wedded to 'one module per pod [per target?]'.  I
don't want a separate pod for RubyGatewayHelpers.  But, unlike SPM, CP is
happy to build mixed Swift-ObjC modules.  So the RubyGatewayHelpers code
is just built as part of RubyGateway.

But, RubyGateway still does `import RubyGatewayHelpers`.  Luckily nothing is
explicitly namespaced, so we just need to make the import pass.  This happens
by creating a dummy module (empty modulemap) during pod install.

Unfortunately, and this is probably not CP's fault, doing it this way makes
it impossible to keep the RubyGatewayHelpers header file out of the RubyGateway
module map, which means users importing RubyGateway also get the `rbg_` symbols
polluting their autocomplete.

Really want to edit the module map after the build is complete, could probably
do via `script_phase` but not sure I want the warning on install / overhead of
maintaining the files.

Everything is just about OK.

## Releasing

* Update docs if needed, separate commit.
* Update podspec, changelog, TODO, README, LICENSE if year changed.
* Commit + tag + push with `--tags`.  Check CI.
* `pod spec lint` -- *not* `pod lib lint`
  * `pod cache clean 'RubyGateway' --all` if you mess up the tag + have to repush it
* `pod trunk me` -- if bad then `pod trunk register` until good
* `pod trunk push`
* Github code -> releases -> tags -> 'Create release'
  * Title is just release triple
  * Paste in changelog section
