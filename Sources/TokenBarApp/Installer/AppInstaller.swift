import AppKit
import Foundation
import TokenBarCore

@MainActor
enum AppInstaller {
    static func installAndRelaunchIfNeeded() -> Bool {
        let language = ((try? JSONSettingsStore().load()) ?? TokenBarSettings()).language
        let sourceURL = Bundle.main.bundleURL.standardizedFileURL
        guard sourceURL.path.hasPrefix("/Volumes/") else {
            return false
        }

        do {
            let destinationURL = try install(sourceURL: sourceURL)
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = false
            configuration.createsNewApplicationInstance = true
            NSWorkspace.shared.openApplication(at: destinationURL, configuration: configuration) { _, error in
                Task { @MainActor in
                    if let error {
                        showFailure(error, language: language)
                        AppServices.shared.start()
                    } else {
                        NSApp.terminate(nil)
                    }
                }
            }
        } catch {
            showFailure(error, language: language)
            return false
        }

        return true
    }

    private static func install(sourceURL: URL) throws -> URL {
        let fileManager = FileManager.default
        let destinations = [
            URL(fileURLWithPath: "/Applications/TokenBar.app"),
            fileManager.homeDirectoryForCurrentUser
                .appending(path: "Applications", directoryHint: .isDirectory)
                .appending(path: "TokenBar.app", directoryHint: .isDirectory)
        ]

        var lastError: Error?
        for destinationURL in destinations {
            do {
                let parentURL = destinationURL.deletingLastPathComponent()
                try fileManager.createDirectory(at: parentURL, withIntermediateDirectories: true)

                let operationID = UUID().uuidString
                let stagingURL = parentURL.appending(
                    path: ".TokenBar.installing-\(operationID).app",
                    directoryHint: .isDirectory
                )
                let backupName = ".TokenBar.backup-\(operationID).app"
                let backupURL = parentURL.appending(path: backupName, directoryHint: .isDirectory)
                defer {
                    try? fileManager.removeItem(at: stagingURL)
                    try? fileManager.removeItem(at: backupURL)
                }

                try fileManager.copyItem(at: sourceURL, to: stagingURL)
                try validateApplication(at: stagingURL)

                if fileManager.fileExists(atPath: destinationURL.path) {
                    _ = try fileManager.replaceItemAt(
                        destinationURL,
                        withItemAt: stagingURL,
                        backupItemName: backupName,
                        options: []
                    )
                } else {
                    try fileManager.moveItem(at: stagingURL, to: destinationURL)
                }

                try validateApplication(at: destinationURL)
                return destinationURL
            } catch {
                lastError = error
            }
        }

        throw lastError ?? CocoaError(.fileWriteNoPermission)
    }

    private static func validateApplication(at url: URL) throws {
        guard
            let bundle = Bundle(url: url),
            bundle.bundleIdentifier == "com.tokenbar.TokenBar",
            let executableURL = bundle.executableURL,
            FileManager.default.isExecutableFile(atPath: executableURL.path)
        else {
            throw InstallerError.invalidApplication
        }
    }

    private static func showFailure(_ error: Error, language: AppLanguage) {
        let strings = TokenBarStrings(language)
        let detail = if let installerError = error as? InstallerError {
            installerError.description(strings: strings)
        } else {
            error.localizedDescription
        }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = strings.installFailedTitle
        alert.informativeText = strings.installFailedDetail(detail)
        alert.addButton(withTitle: strings.ok)
        alert.runModal()
    }
}

private enum InstallerError: Error {
    case invalidApplication

    func description(strings: TokenBarStrings) -> String {
        strings.invalidApplication
    }
}
