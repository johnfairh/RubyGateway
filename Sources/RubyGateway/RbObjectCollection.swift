//
//  RbObjectCollection.swift
//  RubyGateway
//
//  Distributed under the MIT license, see LICENSE
//

/// A view onto a Ruby array using Swift collection protocols.
///
/// This is an adapter type that wraps an `RbObject` and adopts
/// Swift collection protocols for use with an underlying Ruby
/// array (or any Ruby object that supports `length`, `[]`, and
/// `[]=`.)
///
/// For example:
/// ```swift
/// myObj.collection.replaceSubrange(lower..<upper, with: otherArray)
/// ```
///
/// This is separate to `RbObject` to avoid dumping all the
/// collection protocol members into its dynamic member lookup
/// namespace.
public struct RbObjectCollection: RandomAccessCollection,
                                  MutableCollection,
                                  RangeReplaceableCollection,
                                  RbObjectConvertible {
    /// Create a collection from an existing Ruby array object.
    ///
    /// The same thing as accessing `RbObject.collection`.
    public init(_ value: RbObject) {
        self.rubyObject = value
    }

    /// The Ruby object for the underlying array.
    public private(set) var rubyObject: RbObject

    /// Create an empty collection - an empty Ruby array.
    public init() {
        self.rubyObject = []
    }

    public var startIndex: Int {
        return 0
    }

    public var endIndex: Int {
        if let lengthObj = try? rubyObject.call("length"),
            let length = Int(lengthObj) {
            return length
        }
        return 0
    }

    public subscript(index: Int) -> RbObject {
        get {
            return rubyObject[index]
        }
        set {
            rubyObject[index] = newValue
        }
    }

    public func index(after i: Int) -> Int {
        return i + 1
    }

    public func index(before i: Int) -> Int {
        return i - 1
    }

    public mutating func replaceSubrange<C>(_ subrange: Range<Int>, with newElements: C) where C: Collection, C.Element: RbObjectConvertible {
        let newArray = Array(newElements)

        // need this next explicitly to avoid an apologetic fatalError() from Swift.
        // "Swift runtime does not yet support dynamically querying conditional conformance"
        let rangeObj = subrange.rubyObject

        rubyObject[rangeObj] = RbObject(newArray)
    }
}
