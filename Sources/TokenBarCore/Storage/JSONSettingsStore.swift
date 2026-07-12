import Foundation

public final class JSONSettingsStore {
    private let url: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(url: URL = TokenBarPaths.settingsFile) {
        self.url = url
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.decoder = JSONDecoder()
    }

    public func load() throws -> TokenBarSettings {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return TokenBarSettings()
        }
        let data = try Data(contentsOf: url)
        return try decoder.decode(TokenBarSettings.self, from: data)
    }

    public func save(_ settings: TokenBarSettings) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try encoder.encode(settings)
        try data.write(to: url, options: .atomic)
    }
}
