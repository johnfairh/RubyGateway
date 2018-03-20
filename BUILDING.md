Notes on how the framework is built.  There is a certain amount of messing
around to comply with the idiosyncracies of / my lack of patience with
Swift Package Manager & Cocoapods.

=== Components ===

* CRuby - system modulemap and headers for libruby
* RubyBridgeHelpers - C code layer, depends on CRuby
* RubyBridge - Swift layer, depends on CRuby and RubyBridgeHelpers.

=== Goals ===

* Users install just one thing (RubyBridge)
  * Users do not need any weird flags or settings.
* Users get just the RubyBridge interface
* Support Xcode/Carthage, SwiftPM (because Linux), CocoaPods.

Haven't managed to meet all these goals :-)

=== Xcode/Carthage ===

CRuby is a git submodule of RubyBridge, refer to it via Xcode options.

RubyBridgeHelpers is a static library wrapped up in a modulemap.

RubyBridge depends on CRuby and RubyBridgeHelpers as modules.

Everything is awesome.

=== Swift PM ===

CRuby is a formal dependency from Package.swift.  The CRuby submodule
checkout is unused.

RubyBridgeHelpers is a static lib, RubyBridge depends on them both like
the Xcode version.

Everything is fine.

=== CocoaPods ===

CRuby is a git submodule of RubyBridge, refer to it via Xcode options.

CocoaPods seems to be wedded to 'one module per pod [per target?]'.  I
don't want a separate pod for RubyBridgeHelpers.  But, unlike SPM, CP is
happy to build mixed Swift-ObjC modules.  So the RubyBridgeHelpers code
is just built as part of RubyBridge.

But, RubyBridge still does `import RubyBridgeHelpers`.  Luckily nothing is
explicitly namespaced, so we just need to make the import pass.  This happens
by creating a dummy module (empty modulemap) during pod install.

Unfortunately, and this is probably not CP's fault, doing it this way makes
it impossible to keep the RubyBridgeHelpers header file out of the RubyBridge
module map, which means users importing RubyBridge also get the `rbb_` symbols
polluting their autocomplete.

Everything is sort of just about OK.
