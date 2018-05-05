## Master

##### Breaking

* Change `kwArgs` to use `DictionaryLiteral`.

##### Enhancements

* Add conditional Set `RbObjectConvertible` conformance.
* Add conditional ArraySlice `RbObjectConvertible` conformance.

##### Bug Fixes

* None.

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
