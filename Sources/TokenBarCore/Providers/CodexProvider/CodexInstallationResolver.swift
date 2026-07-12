import AppKit
import Darwin
import Foundation

public enum CodexInstallationSource: String, Codable, Equatable, Sendable {
    case application
    case standaloneCLI
}

public struct CodexInstallation: Equatable, Sendable {
    public var source: CodexInstallationSource
    public var executableURL: URL
    public var applicationURL: URL?
    public var bundleIdentifier: String?
    public var displayName: String
    public var applicationVersion: String?
    public var cliVersion: String

    public init(
        source: CodexInstallationSource,
        executableURL: URL,
        applicationURL: URL? = nil,
        bundleIdentifier: String? = nil,
        displayName: String,
        applicationVersion: String? = nil,
        cliVersion: String
    ) {
        self.source = source
        self.executableURL = executableURL
        self.applicationURL = applicationURL
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
        self.applicationVersion = applicationVersion
        self.cliVersion = cliVersion
    }

    public func configuration(timeoutSeconds: TimeInterval) -> CodexProviderConfiguration {
        switch source {
        case .application:
            CodexProviderConfiguration(
                installationMode: .application,
                applicationPath: applicationURL?.path,
                applicationBundleIdentifier: bundleIdentifier,
                executable: executableURL.path,
                timeoutSeconds: timeoutSeconds
            )
        case .standaloneCLI:
            CodexProviderConfiguration(
                installationMode: .customExecutable,
                executable: executableURL.path,
                timeoutSeconds: timeoutSeconds
            )
        }
    }
}

public enum CodexInstallationError: Error, Equatable, Sendable {
    case notFound
    case sourceMissing
    case classicUnsupported
    case invalidApplication
    case invalidExecutable
    case validationTimedOut
    case commandFailed(String)
}

public struct CodexInstallationResolver: @unchecked Sendable {
    public static let codexBundleIdentifier = "com.openai.codex"
    public static let classicBundleIdentifier = "com.openai.chat"
    public static let bundledExecutablePath = "Contents/Resources/codex"

    public init() {}

    public func resolve(
        configuration: CodexProviderConfiguration,
        validationTimeout: TimeInterval = 3
    ) throws -> CodexInstallation {
        switch configuration.installationMode {
        case .automatic:
            return try resolveAutomatically(validationTimeout: validationTimeout)
        case .application:
            if let applicationPath = configuration.applicationPath {
                let applicationURL = URL(fileURLWithPath: applicationPath, isDirectory: true)
                if FileManager.default.fileExists(atPath: applicationURL.path) {
                    return try resolveApplication(at: applicationURL, validationTimeout: validationTimeout)
                }
            }
            if let bundleIdentifier = configuration.applicationBundleIdentifier,
               let applicationURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
                return try resolveApplication(at: applicationURL, validationTimeout: validationTimeout)
            }
            throw CodexInstallationError.sourceMissing
        case .customExecutable:
            return try resolveExecutable(
                at: URL(fileURLWithPath: configuration.executable),
                validationTimeout: validationTimeout
            )
        }
    }

    public func resolveAutomatically(validationTimeout: TimeInterval = 3) throws -> CodexInstallation {
        for applicationURL in automaticApplicationCandidates() {
            guard FileManager.default.fileExists(atPath: applicationURL.path) else { continue }
            if let installation = try? resolveApplication(
                at: applicationURL,
                validationTimeout: validationTimeout
            ) {
                return installation
            }
        }

        for executableURL in automaticExecutableCandidates() {
            guard FileManager.default.isExecutableFile(atPath: executableURL.path) else { continue }
            if let installation = try? resolveExecutable(
                at: executableURL,
                validationTimeout: validationTimeout
            ) {
                return installation
            }
        }
        throw CodexInstallationError.notFound
    }

    public func resolveApplication(
        at applicationURL: URL,
        validationTimeout: TimeInterval = 3
    ) throws -> CodexInstallation {
        guard applicationURL.pathExtension.lowercased() == "app",
              let bundle = Bundle(url: applicationURL) else {
            throw CodexInstallationError.invalidApplication
        }
        if bundle.bundleIdentifier == Self.classicBundleIdentifier {
            throw CodexInstallationError.classicUnsupported
        }

        let executableURL = applicationURL.appending(path: Self.bundledExecutablePath)
        let cliVersion = try validateExecutable(at: executableURL, timeout: validationTimeout)
        let displayName = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? applicationURL.deletingPathExtension().lastPathComponent
        let applicationVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String

        return CodexInstallation(
            source: .application,
            executableURL: executableURL,
            applicationURL: applicationURL,
            bundleIdentifier: bundle.bundleIdentifier,
            displayName: displayName,
            applicationVersion: applicationVersion,
            cliVersion: cliVersion
        )
    }

    public func resolveExecutable(
        at executableURL: URL,
        validationTimeout: TimeInterval = 3
    ) throws -> CodexInstallation {
        let standardizedURL = executableURL.standardizedFileURL.resolvingSymlinksInPath()
        let version = try validateExecutable(at: standardizedURL, timeout: validationTimeout)
        return CodexInstallation(
            source: .standaloneCLI,
            executableURL: standardizedURL,
            displayName: "Codex CLI",
            cliVersion: version
        )
    }

    private func automaticApplicationCandidates() -> [URL] {
        var candidates: [URL] = []
        if let installed = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: Self.codexBundleIdentifier
        ) {
            candidates.append(installed)
        }
        candidates.append(URL(fileURLWithPath: "/Applications/ChatGPT.app", isDirectory: true))
        candidates.append(
            FileManager.default.homeDirectoryForCurrentUser
                .appending(path: "Applications/ChatGPT.app", directoryHint: .isDirectory)
        )
        candidates.append(URL(fileURLWithPath: "/Applications/Codex.app", isDirectory: true))
        return unique(candidates)
    }

    private func automaticExecutableCandidates() -> [URL] {
        var candidates = [
            URL(fileURLWithPath: "/opt/homebrew/bin/codex"),
            URL(fileURLWithPath: "/usr/local/bin/codex"),
            FileManager.default.homeDirectoryForCurrentUser.appending(path: ".local/bin/codex")
        ]
        let pathEntries = ProcessInfo.processInfo.environment["PATH"]?
            .split(separator: ":")
            .map(String.init) ?? []
        candidates.append(contentsOf: pathEntries.map {
            URL(fileURLWithPath: $0, isDirectory: true).appending(path: "codex")
        })
        return unique(candidates)
    }

    private func validateExecutable(at url: URL, timeout: TimeInterval) throws -> String {
        guard FileManager.default.isExecutableFile(atPath: url.path) else {
            throw CodexInstallationError.invalidExecutable
        }

        let process = Process()
        let output = Pipe()
        process.executableURL = url
        process.arguments = ["--version"]
        process.standardOutput = output
        process.standardError = output

        let semaphore = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in semaphore.signal() }
        do {
            try process.run()
        } catch {
            throw CodexInstallationError.commandFailed(error.localizedDescription)
        }

        if semaphore.wait(timeout: .now() + timeout) == .timedOut {
            let pid = process.processIdentifier
            process.terminate()
            if process.isRunning { Darwin.kill(pid, SIGKILL) }
            throw CodexInstallationError.validationTimedOut
        }

        let data = output.fileHandleForReading.readDataToEndOfFile()
        let version = String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard process.terminationStatus == 0,
              version.lowercased().contains("codex") else {
            throw CodexInstallationError.invalidExecutable
        }
        return version
    }

    private func unique(_ urls: [URL]) -> [URL] {
        urls.reduce(into: [URL]()) { result, url in
            let standardized = url.standardizedFileURL
            if !result.contains(standardized) { result.append(standardized) }
        }
    }
}
