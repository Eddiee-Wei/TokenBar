import Foundation
import Testing
@testable import TokenBarCore

@Suite("Codex installation resolution")
struct CodexInstallationResolverTests {
    @Test("Accepts the current ChatGPT Codex application")
    func resolvesCurrentApplication() throws {
        let fixture = try makeApplication(bundleIdentifier: "com.openai.codex", includeCodex: true)
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        let installation = try CodexInstallationResolver().resolveApplication(at: fixture.app)

        #expect(installation.source == .application)
        #expect(installation.bundleIdentifier == "com.openai.codex")
        #expect(installation.cliVersion == "codex-cli 0.144.0")
        #expect(installation.executableURL.path.hasSuffix("Contents/Resources/codex"))
    }

    @Test("Rejects ChatGPT Classic even if a similarly named executable exists")
    func rejectsClassicApplication() throws {
        let fixture = try makeApplication(bundleIdentifier: "com.openai.chat", includeCodex: true)
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        #expect(throws: CodexInstallationError.classicUnsupported) {
            try CodexInstallationResolver().resolveApplication(at: fixture.app)
        }
    }

    @Test("Rejects applications without the bundled Codex CLI")
    func rejectsApplicationWithoutCodex() throws {
        let fixture = try makeApplication(bundleIdentifier: "com.example.empty", includeCodex: false)
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        #expect(throws: CodexInstallationError.invalidExecutable) {
            try CodexInstallationResolver().resolveApplication(at: fixture.app)
        }
    }

    @Test("Accepts a standalone Codex executable")
    func resolvesStandaloneExecutable() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "TokenBarResolver-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let executable = root.appending(path: "codex")
        try writeExecutable(at: executable)

        let installation = try CodexInstallationResolver().resolveExecutable(at: executable)

        #expect(installation.source == .standaloneCLI)
        #expect(installation.displayName == "Codex CLI")
        #expect(installation.cliVersion == "codex-cli 0.144.0")
    }

    @Test("Stops validation when an executable does not respond")
    func timesOutValidation() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "TokenBarResolver-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let executable = root.appending(path: "codex")
        try Data("#!/bin/sh\nsleep 2\necho \"codex-cli delayed\"\n".utf8).write(to: executable)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: executable.path
        )

        let startedAt = Date()
        #expect(throws: CodexInstallationError.validationTimedOut) {
            try CodexInstallationResolver().resolveExecutable(
                at: executable,
                validationTimeout: 0.05
            )
        }
        #expect(Date().timeIntervalSince(startedAt) < 1)
    }

    private func makeApplication(
        bundleIdentifier: String,
        includeCodex: Bool
    ) throws -> (root: URL, app: URL) {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "TokenBarResolver-\(UUID().uuidString)", directoryHint: .isDirectory)
        let app = root.appending(path: "ChatGPT.app", directoryHint: .isDirectory)
        let contents = app.appending(path: "Contents", directoryHint: .isDirectory)
        let resources = contents.appending(path: "Resources", directoryHint: .isDirectory)
        let macOS = contents.appending(path: "MacOS", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: macOS, withIntermediateDirectories: true)

        let info: [String: Any] = [
            "CFBundleIdentifier": bundleIdentifier,
            "CFBundleName": "ChatGPT",
            "CFBundleDisplayName": "ChatGPT",
            "CFBundleShortVersionString": "26.707.31428",
            "CFBundleExecutable": "ChatGPT"
        ]
        let plist = try PropertyListSerialization.data(
            fromPropertyList: info,
            format: .xml,
            options: 0
        )
        try plist.write(to: contents.appending(path: "Info.plist"))
        try writeExecutable(at: macOS.appending(path: "ChatGPT"), output: "fixture")
        if includeCodex {
            try writeExecutable(at: resources.appending(path: "codex"))
        }
        return (root, app)
    }

    private func writeExecutable(at url: URL, output: String = "codex-cli 0.144.0") throws {
        try Data("#!/bin/sh\necho \"\(output)\"\n".utf8).write(to: url)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: url.path
        )
    }
}
