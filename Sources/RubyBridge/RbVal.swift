//
//  RbVal.swift
//  TMLRuby
//
//  Created by John Fairhurst on 19/02/2018.
//
import RubyBridgeHelpers

/// Wrap up a Ruby value.
open class RbVal {
    private let valueBox: UnsafeMutablePointer<Rbb_value>

    /// Wrap up a Ruby value returned by its API and keep it safe from GC.
    public init(rubyValue: VALUE) {
        valueBox = rbb_value_alloc(rubyValue);
    }

    /// Create another Swift reference to an existing `RbVal`.
    /// The underlying Ruby value will not be GCed until both
    /// `RbVal`s have gone out of scope.
    public init(_ copy: RbVal) {
        valueBox = rbb_value_dup(copy.valueBox);
    }

    /// Allow this `VALUE` to be GCed when we go out of scope.
    deinit {
        rbb_value_free(valueBox)
    }

    /// Access the `VALUE` object for use with the `CRuby` API.
    ///
    /// If you keep hold of this `VALUE` after the `RbVal` has been
    /// deinitialized then you become responsible for making sure Ruby
    /// does not garbage collect it.
    ///
    /// It works best to keep the `RbVal` around and use this attribute
    /// accessor directly with the API
    public var rubyValue: VALUE {
        return valueBox.pointee.value
    }
}
