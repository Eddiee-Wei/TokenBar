import Foundation

public protocol QuotaProvider: Sendable {
    var descriptor: ProviderDescriptor { get }
    func refresh() async -> QuotaProviderUpdate
    func authStatus() async -> ProviderAuthStatus
}

public extension QuotaProvider {
    func unsupportedUpdate(_ message: String) -> QuotaProviderUpdate {
        QuotaProviderUpdate(
            providerID: descriptor.id,
            displayName: descriptor.displayName,
            status: .unsupported,
            message: message,
            usageURL: descriptor.usageURL
        )
    }

    func errorUpdate(_ error: ProviderError, language: AppLanguage = .english) -> QuotaProviderUpdate {
        QuotaProviderUpdate(
            providerID: descriptor.id,
            displayName: descriptor.displayName,
            status: error.status,
            message: error.userMessage(language: language),
            usageURL: descriptor.usageURL
        )
    }
}

public struct ProviderRegistry {
    public var providers: [any QuotaProvider]

    public init(providers: [any QuotaProvider]) {
        self.providers = providers
    }

    public static func makeDefault(settings: TokenBarSettings) -> ProviderRegistry {
        ProviderRegistry(providers: [CodexProvider(configuration: settings.codex, language: settings.language)])
    }
}
