//
//  VMWrapper.swift
//  TMLRubyTests
//
//  Created by John Fairhurst on 13/02/2018.
//

import Foundation
import RubyBridge

/// Misc test helpers
struct Helpers {
    /// Ruby's lifetime rules mean that we can't create + tear down VMs willy-nilly as
    /// one would naturally do in a test environment.  So we set up a singleton here.
    ///
    /// To test that 'cleanup' actually works we will need a second test target (and hope
    /// that the test runner will treat that as a separate process.)
    static var ruby: RbVM = { try! RbVM() }()

    /// Ruby files etc.
    private static var fixturesDir: String = {  URL(fileURLWithPath: #file).deletingLastPathComponent().path + "/Fixtures" }()

    /// Get full path to fixture with name
    static func fixturePath(_ name: String) -> String {
        return "\(fixturesDir)/\(name)"
    }
}
