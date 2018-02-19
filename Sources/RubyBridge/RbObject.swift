//
//  RbObject.swift
//  RubyBridge
//
//  Distributed under the MIT license, see LICENSE
//
import RubyBridgeHelpers

/// Wraps a Ruby object
open class RbObject {
    private let valueBox: UnsafeMutablePointer<Rbb_value>

    /// Wrap up a Ruby object using the `VALUE` handle
    /// returned by its API, keep the object safe from garbage collection.
    public init(rubyValue: VALUE) {
        valueBox = rbb_value_alloc(rubyValue);
    }

    /// Create another Swift reference to an existing `RbObject`.
    /// The underlying Ruby object will not be GCed until both
    /// `RbObject`s have gone out of scope.
    public init(_ copy: RbObject) {
        valueBox = rbb_value_dup(copy.valueBox);
    }

    /// Allow the tracked object to be GCed when we go out of scope.
    deinit {
        rbb_value_free(valueBox)
    }

    /// Access the `VALUE` object handle for use with the `CRuby` API.
    ///
    /// If you keep hold of this `VALUE` after the `RbObject` has been
    /// deinitialized then you are responsible for making sure Ruby
    /// does not garbage collect it before you are done with it.
    ///
    /// It works best to keep the `RbObject` around and use this attribute
    /// accessor directly with the API
    public var rubyValue: VALUE {
        return valueBox.pointee.value
    }
}
