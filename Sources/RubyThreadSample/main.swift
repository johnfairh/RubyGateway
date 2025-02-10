//
//  main.swift
//  RubyThreadSample
//
//  Distributed under the MIT license, see LICENSE
//
import RubyGateway

@available(macOS 14, *)
actor RubyActor {
    nonisolated let unownedExecutor: UnownedSerialExecutor
    init(executor: RubyExecutor) {
        self.unownedExecutor = executor.asUnownedSerialExecutor()
    }

    func rand() async throws -> String {
        let ver = Ruby.version
        let result = try Ruby.eval(ruby: "Kernel.rand")
        return "Ruby (\(ver)) random: \(result)"
    }
}

@MainActor
@available(macOS 14, *)
func doRubyWork() async {
    do {
        let executor = RubyExecutor()
        let actor = RubyActor(executor: executor)
        let result = try await actor.rand()
        print(result)
        // This is optional - fine to just let the process exit.
        executor.stop()
    } catch {
        print("error: \(error)")
    }
}

if #available(macOS 14, *) {
    await doRubyWork()
}
