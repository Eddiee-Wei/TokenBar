import Foundation
import Testing
@testable import TokenBarCore

@Suite("Codex app-server client")
struct CodexAppServerClientTests {
    @Test("Uses structured JSON-RPC and receives rolling updates", .timeLimit(.minutes(1)))
    func readsLimitsAndReceivesNotification() async throws {
        let executable = try makeMockExecutable(mode: .success)
        defer { try? FileManager.default.removeItem(at: executable.deletingLastPathComponent()) }
        let client = CodexAppServerClient(executable: executable.path, timeoutSeconds: 2, clientVersion: "test")
        let stream = await client.rateLimitUpdates()
        let eventTask = Task { await firstEvent(in: stream, timeout: .seconds(2)) }

        let response = try await client.readRateLimits()
        let receivedEvent = await eventTask.value
        await client.stop()

        #expect(response.rateLimits.primary?.usedPercent == 25)
        #expect(receivedEvent)
    }

    @Test("Times out and tears down an unresponsive process", .timeLimit(.minutes(1)))
    func timesOut() async throws {
        let executable = try makeMockExecutable(mode: .timeout)
        defer { try? FileManager.default.removeItem(at: executable.deletingLastPathComponent()) }
        let client = CodexAppServerClient(executable: executable.path, timeoutSeconds: 0.2, clientVersion: "test")
        await #expect(throws: ProviderError.self) {
            _ = try await client.readRateLimits()
        }
        await client.stop()
    }

    private enum MockMode { case success, timeout }

    private func makeMockExecutable(mode: MockMode) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "TokenBarMock-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let executable = directory.appending(path: "codex-mock")
        let body: String
        switch mode {
        case .success:
            body = """
            #!/bin/sh
            while IFS= read -r line; do
              case "$line" in
                *initialize*) printf '%s\\n' '{"result":{"server":"mock"},"id":0}' ;;
                *rateLimits*)
                  printf '%s\\n' '{"result":{"rateLimits":{"primary":{"usedPercent":25,"windowDurationMins":300}}},"id":1}'
                  printf '%s\\n' '{"method":"account/rateLimits/updated","params":{"rateLimits":{"primary":{"usedPercent":26}}}}'
                  ;;
              esac
            done
            """
        case .timeout:
            body = """
            #!/bin/sh
            while IFS= read -r line; do sleep 5; done
            """
        }
        try body.write(to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
        return executable
    }

    private func firstEvent(in stream: AsyncStream<Void>, timeout: Duration) async -> Bool {
        await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                var iterator = stream.makeAsyncIterator()
                return await iterator.next() != nil
            }
            group.addTask {
                try? await Task.sleep(for: timeout)
                return false
            }
            let result = await group.next() ?? false
            group.cancelAll()
            return result
        }
    }
}
