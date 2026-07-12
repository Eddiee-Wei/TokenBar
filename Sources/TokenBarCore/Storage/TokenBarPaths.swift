import Foundation

public enum TokenBarPaths {
    public static var applicationSupportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        return base.appending(path: "TokenBar", directoryHint: .isDirectory)
    }

    public static var settingsFile: URL {
        applicationSupportDirectory.appending(path: "settings.json")
    }

    public static func ensureApplicationSupportDirectory() throws {
        try FileManager.default.createDirectory(
            at: applicationSupportDirectory,
            withIntermediateDirectories: true
        )
    }
}
