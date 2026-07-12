import Foundation

public struct CodexProvider: QuotaProvider {
    public let descriptor: ProviderDescriptor
    private let client: CodexAppServerClient
    private let language: AppLanguage

    public init(configuration: CodexProviderConfiguration, language: AppLanguage = .english) {
        self.language = language
        self.descriptor = ProviderDescriptor(
            id: .codex,
            capabilities: [.liveRateLimit, .usageHistory, .dashboardDeepLink],
            usageURL: URL(string: "https://chatgpt.com/codex/settings/usage")
        )
        self.client = CodexAppServerClient(
            executable: configuration.executable,
            timeoutSeconds: configuration.timeoutSeconds,
            language: language
        )
    }

    public func authStatus() async -> ProviderAuthStatus {
        .unknown
    }

    public func refresh() async -> QuotaProviderUpdate {
        do {
            let response = try await client.readRateLimits()
            let snapshots = CodexRateLimitParser.snapshots(from: response, language: language)
            guard let snapshot = CodexRateLimitParser.tightestSnapshot(in: snapshots) else {
                throw ProviderError.invalidResponse(
                    TokenBarStrings(language).text(
                        "The Codex response contains no usable quota windows.",
                        "Codex 额度响应里没有可用的额度窗口。"
                    )
                )
            }
            return QuotaProviderUpdate(
                providerID: descriptor.id,
                displayName: descriptor.displayName,
                status: CodexRateLimitParser.isLimited(response) || snapshot.severity == .critical ? .limited : .ok,
                snapshot: snapshot,
                snapshots: snapshots,
                usageURL: descriptor.usageURL
            )
        } catch let error as ProviderError {
            return errorUpdate(error, language: language)
        } catch {
            let message = TokenBarStrings(language).text(
                "Codex app-server is unavailable. Open Codex and check /status, or verify that `codex app-server` runs correctly.",
                "Codex app-server 不可用。请打开 Codex 使用 /status，或确认 `codex app-server` 可以正常运行。"
            )
            return errorUpdate(.commandFailed(message), language: language)
        }
    }

    public func rateLimitUpdates() async -> AsyncStream<Void> {
        await client.rateLimitUpdates()
    }

    public func stop() async {
        await client.stop()
    }
}
