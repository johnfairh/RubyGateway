//
//  RbSymbol.swift
//  RubyGateway
//
//  Distributed under the MIT license, see LICENSE
//

import CRuby

/// Represent a Ruby symbol.
///
/// Ruby symbols are written `:name`.  If in Ruby you would write:
/// ```ruby
/// obj.meth(:value)
/// ```
///
/// Then the RubyGateway version is:
/// ```swift
/// try obj.call("meth", args: [RbSymbol("value")])
/// ```
public struct RbSymbol: RbObjectConvertible {
    private let name: String

    /// Create from the name for the symbol.  No leading colon.
    public init(_ name: String) {
        self.name = name
    }

    /// Try to create an `RbSymbol` from an `RbObject`.
    ///
    /// Always fails - no use for this, just use the `RbObject`.
    /// :nodoc:
    public init?(_ value: RbObject) {
        return nil
    }

    /// A Ruby object for the symbol
    public var rubyObject: RbObject {
        guard Ruby.softSetup(),
            let id = try? Ruby.getID(for: name) else {
                return .nilObject
        }
        return RbObject(rubyValue: rb_id2sym(id))
    }
}

// MARK: - CustomStringConvertible

extension RbSymbol: CustomStringConvertible {
    /// A textual representation of the `RbSymbol`
    public var description: String {
        return "RbSymbol(\(name))"
    }
}
