//
//  RbObjectCollection.swift
//  RubyGateway
//
//  Distributed under the MIT license, see LICENSE
//

public struct RbObjectCollection: RandomAccessCollection, MutableCollection {
    private let object: RbObject

    public init(object: RbObject) {
        self.object = object
    }

    public var startIndex: RbObject { return 0 }
    public var endIndex: RbObject {
        return try! object.call("length")
    }

    public subscript(index: RbObject) -> RbObject {
        get {
            return object[index]
        }
        set {
            self[index] = newValue
        }
    }

    public func index(after i: RbObject) -> RbObject {
        return i + 1
    }

    public func index(before i: RbObject) -> RbObject {
        return i - 1
    }

    // MARK: - RandomAccessCollection

    public func index(_ i: RbObject, offsetBy n: RbObject) -> RbObject {
        return i + n
    }

    public func distance(from start: RbObject, to end: RbObject) -> RbObject {
        return end - start
    }
}

// MARK: - RangeReplaceableCollection

extension RbObjectCollection: RangeReplaceableCollection {

    public init() {
        self.object = []
    }

    public mutating func replaceSubrange<C>(_ subrange: Range<RbObject>, with newElements: C) where C : Collection, C.Element: RbObjectConvertible {
        let newArray = Array(newElements)
        object[subrange] = RbObject(newArray)
    }
}
