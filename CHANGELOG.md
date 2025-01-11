## 6.1.0 -- 11th January 2025

* Support Ruby 3.4

## 6.0.0 - 19th September 2024

Swift 6 and concurrency support

* More concurrency-correct API changes
* Split "call-with-Swift-block" methods into two versions: one taking
  a non-escaping non-sendable closure for immediate evaluation, and
  the other taking a sendable, escaping closure for future use
* Updated documentation for Linux workarounds

## 6.0.0-pre1 - 23rd April 2024

First release leading up to Swift 6.

* Revamp for modern Swift including concurrency
  checking, many technically-changed APIs
* Update CRuby, introduce xcconfig

## 5.5.0 - 30th January 2024

#### Enhancements

* Support Ruby 3.3

## 5.4.0 - 27th January 2023

#### Enhancements

* Support Ruby 3.2

## 5.3.0 - 20th October 2022

#### Enhancements

* Support Ruby 3.1

## 5.2.0 - 2nd October 2021

#### Enhancements

* Support building cleanly with Xcode13 GA.  
  [Karim Alweheshy](https://github.com/karimalweheshy)

## 5.1.0 - 2nd July 2021

#### Breaking

* Removed `RbGateway.taintChecks` -- `$SAFE` removed in Ruby 3
* Internal modules `CRuby` and `RubyGatewayHelpers` are now imported as
  `@_implementationOnly`

#### Enhancements

* Support Ruby 3 - check README notes on `-fdeclspec`, see CI for an example
* Support building cleanly with Xcode 13
* Add `kwArgs` parameter to `RbMethod.yieldBlock(...)`

## 4.0.0 - 18th May 2021

#### Breaking

* Require minimum Swift 5.4 / Xcode 12.5
* Require minimum Ruby 2.6

## 3.2.1 - 11th May 2020

#### Bug Fixes

* Fix warnings and tests for Swift 5.2/Xcode 11.4.

## 3.2.0 - 11th December 2019

#### Breaking

* None

#### Enhancements

* Add `RbObjectAccess.setConstant(_:newValue:)`, somehow overlooked!
* Add `RbGateway.setArguments(_:)` to help with ARGV-setting.

#### Bug Fixes

* None

## 3.1.0 - 29th October 2019

#### Enhancements

* Add `Hashable` conformance to `RbSymbol`.
* Tests pass on Ruby 2.6 / Xcode 11.2.

## 3.0.0 - 16th June 2019

##### Breaking

* Require minimum Swift 5 / Xcode 10.2 / Ruby 2.3.
* Standardize all APIs to not require a leading `name` arg label.
* Retire @dynamicMemberLookup support now the level of support from Swift
  is clearer.  May revisit this in future.

##### Enhancements

* Implement class and singleton-class methods in Swift.
* Define classes and modules from Swift.
* Add module mix-in functions to `RbObject`.
* Bind Ruby objects and methods directly to Swift objects and methods.
* Add throwing conversion as alternative to optional initializer.
* Add `RbMethod.callSuper()` to call superclass method.

##### Bug Fixes

## 2.1.0 - 18th December 2018

##### Enhancements

* Implement global functions in Swift.

##### Bug Fixes

* Ruby nil coerced to Dictionary should give empty not Swift nil.

## 2.0.0 - 8th October 2018

##### Breaking

* Require Swift 4.2.

##### Enhancements

* Dynamic member lookup for property access or 0-arg methods.
* Global variables can use native Swift types.

## 1.1.0 - 18th July 2018

* Add `RbComplex` wrapper for Ruby Complex.
* Add `RbRational` wrapper for Ruby Rational.
* Add `RbGateway.defineGlobalVar` - dynamically implement Ruby global
  variables in Swift.

## 1.0.0 - 11th May 2018

* Add `RbGateway.taintChecks`.
* Full SemVer rules from now on.

## 0.5.0 - 5th May 2018

##### Breaking

* Change `kwArgs` to use `DictionaryLiteral` per dynamic callable.

##### Enhancements

* Add conditional Set `RbObjectConvertible` conformance.
* Add conditional ArraySlice `RbObjectConvertible` conformance.

## 0.4.0 - 20th April 2018

##### Breaking

* Require Swift 4.1 (conditional conformances).
* Replace `RbObject`'s `CustomPlaygroundQuickLookable` conformance with
  `CustomPlaygroundDisplayConvertible`.

##### Enhancements

* Add conditional Array `RbObjectConvertible` conformance.
* Add conditional Dictionary `RbObjectConvertible` conformance.
* Add `RbThread` utilities and rules for multithreading.
* Add conditional Range family `RbObjectConvertible` conformance.
* Add `RbObjectCollection` to use Swift collection protocols with Ruby.
* Allow Swift `nil` literal in argument positions to mean Ruby `nil`.

## 0.3.0 - 21st March 2018

CocoaPods.

## 0.2.0 - 19th March 2018

Add `RbProc` `RbBlockCallback` `RbBreak` and new `RbObjectAccess.call(...)`
variants to let Swift code implement Ruby blocks.

## 0.1.0 - 12th March 2018

Basic data types and object access.

Swift PM and Carthage.
