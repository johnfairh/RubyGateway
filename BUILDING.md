Notes on how the framework is built.  There is a certain amount of messing
around to comply with the idiosyncracies of / my lack of patience with
Swift Package Manager.

## Components 

* CRuby - system modulemap and headers for libruby
* RubyGatewayHelpers - C code layer, depends on CRuby
* RubyGateway - Swift layer, depends on CRuby and RubyGatewayHelpers.

## Goals 

* Users install just one thing (RubyGateway)
  * Users do not need any weird flags or settings.
* Users get just the RubyGateway interface
* Support Xcode/Carthage, SwiftPM (because Linux)

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

## Ruby 3 notes

Spell to get Swift docs for CRuby if Xcode can't do it:
```shell
jazzy --min-acl private --module CRuby --swift-build-tool symbolgraph --build-tool-arguments -I,/Users/johnf/.rbenv/versions/3.0.0/include/ruby-3.0.0/x86_64-darwin20,-I,/Users/johnf/.rbenv/versions/3.0.0/include/ruby-3.0.0,-I,$(pwd),-Xcc,-fdeclspec
```

## Releasing

* Update changelog, .jazzy.yaml, TODO, README, LICENSE if year changed.
* Update docs if needed, separate commit.
* Commit + tag + push with `--tags`.  Check CI.
* Github code -> releases -> tags -> 'Create release'
  * Title is just release triple
  * Paste in changelog section
