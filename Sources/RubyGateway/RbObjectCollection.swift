//
//  RbObjectCollection.swift
//  RubyGateway
//
//  Distributed under the MIT license, see LICENSE
//

public struct RbObjectCollection: RandomAccessCollection, MutableCollection, RangeReplaceableCollection {
    private let object: RbObject

    public init(object: RbObject) {
        self.object = object
    }

    public init() {
        self.object = []
    }

    public var startIndex: Int { return 0 }
    public var endIndex: Int {
        return Int(try! object.call("length"))!
    }

    public subscript(index: Int) -> RbObject {
        get {
            return object[index]
        }
        set {
            self[index] = newValue
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
        object[subrange] = RbObject(newArray)
    }
}
