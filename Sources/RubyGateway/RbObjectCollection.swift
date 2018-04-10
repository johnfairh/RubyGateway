//
//  RbObjectCollection.swift
//  RubyGateway
//
//  Distributed under the MIT license, see LICENSE
//

public struct RbObjectCollection: RandomAccessCollection,
                                  MutableCollection,
                                  RangeReplaceableCollection,
                                  RbObjectConvertible {
    public init(_ value: RbObject) {
        self.rubyObject = value
    }

    public private(set) var rubyObject: RbObject

    public init() {
        self.rubyObject = []
    }

    public var startIndex: Int { return 0 }
    public var endIndex: Int {
        return Int(try! rubyObject.call("length"))! /* XXX */
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
