//
//  String+RubyGateway.swift
//  RubyGateway
//
//  Distributed under the MIT license, see LICENSE

// These hints are used to direct the 'smart' `RbInstanceAccess.get(...)`
// method, rather than anything that relies on them being completely
// correct - see true story in `rb_enc_symname_type()`.

import CRuby

extension String {
    /// Helper to test type and throw if wrong
    private func check(_ predPath: KeyPath<String, Bool>, _ type: String) throws {
        guard self[keyPath: predPath] else {
            throw RbError.badIdentifier(type: type, id: self)
        }
    }

    /// Does the string look like a Ruby constant name?
    var isRubyConstantName: Bool {
        // Ruby supports full utf8 character set for identifiers.
        // However Ruby constants are defined as beginning with an ASCII
        // capital letter.  `rb_isupper` is locale-insensitive.
        if let firstChar = utf8.first {
            return rb_isupper(Int32(firstChar)) != 0
        }
        return false
    }

    /// Does the string look like a Ruby constant path name?
    var isRubyConstantPath: Bool {
        guard !hasSuffix("::") else {
            return false
        }
        let pathComponents = components(separatedBy: "::")
        guard !pathComponents.isEmpty else {
            return false
        }
        return pathComponents.allSatisfy { $0.isRubyConstantName }
    }

    /// Throw if the string does not look like a constant path.
    func checkRubyConstantPath() throws {
        try check(\String.isRubyConstantPath, "constant (capital)")
    }

    /// Does the string look like a Ruby global variable name?
    var isRubyGlobalVarName: Bool {
        return starts(with: "$")
    }

    /// Throw if the string does not look like a global variable name.
    func checkRubyGlobalVarName() throws {
        try check(\String.isRubyGlobalVarName, "global var ($)")
    }

    /// Does the string look like a Ruby instance variable name?
    var isRubyInstanceVarName: Bool {
        return starts(with: "@") && !isRubyClassVarName
    }

    /// Throw if the string does not look like an instance var name.
    func checkRubyInstanceVarName() throws {
        try check(\String.isRubyInstanceVarName, "instance var (@)")
    }

    /// Does the string look like a Ruby class variable name?
    var isRubyClassVarName: Bool {
        return starts(with: "@@")
    }

    /// Throw if the string does not look like a class var name.
    func checkRubyClassVarName() throws {
        try check(\String.isRubyClassVarName, "class var (@@)")
    }

    /// Does the string look like a Ruby method name?
    var isRubyMethodName: Bool {
        return !isRubyConstantName && !isRubyGlobalVarName && !isRubyInstanceVarName && !isRubyClassVarName
    }

    /// Throw if the string does not look like a method name.
    func checkRubyMethodName() throws {
        try check(\String.isRubyMethodName, "method")
    }
}

extension String {
    /// Split a constant path into an ancestors path and a leaf name
    func decomposedConstantPath() throws -> (String?, String) {
        try checkRubyConstantPath()
        let pathComponents = components(separatedBy: "::")
        let constant = pathComponents.last! // because checkRubyConstantPath
        let ancestors = pathComponents.dropLast()
        guard !ancestors.isEmpty else {
            return (nil, constant)
        }
        return (ancestors.joined(separator: "::"), constant)
    }
}
