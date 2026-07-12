import AppKit
import Combine
import Foundation
import TokenBarCore

@MainActor
final class TokenBarAppModel: ObservableObject {
    @Published var settings: TokenBarSettings
    @Published var updates: [ProviderID: QuotaProviderUpdate] = [:]
    @Published var isRefreshing = false
    @Published var lastError: String?
    @Published private(set) var resolvedInstallation: CodexInstallation?
    @Published private(set) var isResolvingCodexSource = false
    @Published private(set) var codexInstallationError: CodexInstallationError?

    private let settingsStore: JSONSettingsStore
    private let notificationService: QuotaNotificationService
    private let launchAtLoginController: LaunchAtLoginController
    private let installationResolver: CodexInstallationResolver
    private var provider: CodexProvider
    private var appliedProviderConfiguration: CodexProviderConfiguration
    private var appliedLanguage: AppLanguage
    private var autoRefreshTask: Task<Void, Never>?
    private var rateLimitUpdateTask: Task<Void, Never>?
    private var activeRefresh: (id: UUID, task: Task<QuotaProviderUpdate, Never>)?
    private var refreshRequestedWhileActive = false

    init(
        settingsStore: JSONSettingsStore = JSONSettingsStore(),
        notificationService: QuotaNotificationService = QuotaNotificationService(),
        launchAtLoginController: LaunchAtLoginController = LaunchAtLoginController(),
        installationResolver: CodexInstallationResolver = CodexInstallationResolver()
    ) {
        self.settingsStore = settingsStore
        self.notificationService = notificationService
        self.launchAtLoginController = launchAtLoginController
        self.installationResolver = installationResolver
        let loadedSettings = (try? settingsStore.load()) ?? TokenBarSettings()
        self.settings = loadedSettings
        self.provider = CodexProvider(
            configuration: loadedSettings.codex,
            language: loadedSettings.language
        )
        self.appliedProviderConfiguration = loadedSettings.codex
        self.appliedLanguage = loadedSettings.language
        startRateLimitUpdates()
        startAutoRefresh()
        Task { [weak self] in await self?.resolveConfiguredCodexSource() }
    }

    deinit {
        autoRefreshTask?.cancel()
        rateLimitUpdateTask?.cancel()
        activeRefresh?.task.cancel()
    }

    var orderedUpdates: [QuotaProviderUpdate] {
        updates[.codex].map { [$0] } ?? []
    }

    var strings: TokenBarStrings {
        TokenBarStrings(settings.language)
    }

    var needsCodexSetup: Bool {
        !isResolvingCodexSource && resolvedInstallation == nil && codexInstallationError != nil
    }

    var codexInstallationErrorMessage: String? {
        codexInstallationError.map { installationErrorMessage($0) }
    }

    var tightestSnapshot: QuotaSnapshot? {
        QuotaSummary.tightestSnapshot(from: orderedUpdates)
    }

    var preferredSnapshot: QuotaSnapshot? {
        QuotaSummary.preferredSnapshot(from: orderedUpdates)
    }

    var menuSnapshot: QuotaSnapshot? {
        QuotaSummary.selectedSnapshot(
            from: orderedUpdates,
            selection: settings.selectedQuota
        )
    }

    var menuTitle: String {
        QuotaSummary.menuTitle(
            from: orderedUpdates,
            selection: settings.selectedQuota
        )
    }

    func selectMenuSnapshot(_ snapshot: QuotaSnapshot) {
        let selection = QuotaSelection(snapshot: snapshot)
        guard settings.selectedQuota != selection else { return }
        settings.selectedQuota = selection
        persistCurrentSettings()
    }

    func isMenuSnapshot(_ snapshot: QuotaSnapshot) -> Bool {
        guard let menuSnapshot else { return false }
        return QuotaSelection(snapshot: menuSnapshot).matches(snapshot)
    }

    func refreshAll() async {
        guard resolvedInstallation != nil, !isResolvingCodexSource else { return }
        if let activeRefresh {
            refreshRequestedWhileActive = true
            _ = await activeRefresh.task.value
            return
        }

        repeat {
            refreshRequestedWhileActive = false
            let refreshID = UUID()
            let provider = self.provider
            let task = Task { await provider.refresh() }
            activeRefresh = (refreshID, task)
            isRefreshing = true

            let update = await task.value
            guard activeRefresh?.id == refreshID else { return }

            let previous = updates[.codex]
            updates[.codex] = update
            activeRefresh = nil

            if settings.notificationsEnabled {
                await notificationService.evaluate(
                    previous: previous,
                    current: update,
                    thresholdPercent: settings.notificationThresholdPercent,
                    language: settings.language
                )
            }
        } while refreshRequestedWhileActive

        isRefreshing = false
    }

    func saveSettings() {
        settings = normalized(settings)

        do {
            try settingsStore.save(settings)
        } catch {
            lastError = error.localizedDescription
            return
        }

        do {
            try launchAtLoginController.apply(
                enabled: settings.launchAtLogin,
                language: settings.language
            )
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }

        if settings.notificationsEnabled {
            Task { [weak self] in
                guard let self else { return }
                let granted = await notificationService.requestAuthorization()
                if !granted {
                    lastError = strings.notificationPermissionDenied
                }
            }
        }

        if appliedProviderConfiguration != settings.codex || appliedLanguage != settings.language {
            rebuildProvider()
        }
        startAutoRefresh()
        Task { [weak self] in await self?.refreshAll() }
    }

    func setLanguage(_ language: AppLanguage) {
        guard settings.language != language else { return }
        settings.language = language
        persistCurrentSettings()
        rebuildProvider()
        Task { [weak self] in await self?.refreshAll() }
    }

    func detectCodexAgain() async {
        let installationResolver = self.installationResolver
        let configuration = CodexProviderConfiguration(
            installationMode: .automatic,
            executable: "codex",
            timeoutSeconds: settings.codex.timeoutSeconds
        )
        await resolve(
            configuration: configuration,
            preservingAutomaticMode: true
        ) {
            try installationResolver.resolveAutomatically()
        }
    }

    func selectCodexApplication(_ applicationURL: URL) async {
        let installationResolver = self.installationResolver
        let configuration = CodexProviderConfiguration(
            installationMode: .application,
            applicationPath: applicationURL.path,
            executable: applicationURL
                .appending(path: CodexInstallationResolver.bundledExecutablePath)
                .path,
            timeoutSeconds: settings.codex.timeoutSeconds
        )
        await resolve(configuration: configuration) {
            try installationResolver.resolveApplication(at: applicationURL)
        }
    }

    func selectCodexExecutable(_ executableURL: URL) async {
        let installationResolver = self.installationResolver
        let configuration = CodexProviderConfiguration(
            installationMode: .customExecutable,
            executable: executableURL.path,
            timeoutSeconds: settings.codex.timeoutSeconds
        )
        await resolve(configuration: configuration) {
            try installationResolver.resolveExecutable(at: executableURL)
        }
    }

    func openCodexUsagePage() {
        guard let url = URL(string: "https://chatgpt.com/codex/settings/usage") else { return }
        NSWorkspace.shared.open(url)
    }

    func openUsagePage(for update: QuotaProviderUpdate) {
        guard let url = update.usageURL else { return }
        NSWorkspace.shared.open(url)
    }

    func shutdown() {
        autoRefreshTask?.cancel()
        rateLimitUpdateTask?.cancel()
        activeRefresh?.task.cancel()
        let provider = self.provider
        Task { await provider.stop() }
    }

    private func rebuildProvider() {
        activeRefresh?.task.cancel()
        activeRefresh = nil
        refreshRequestedWhileActive = false
        isRefreshing = false
        rateLimitUpdateTask?.cancel()
        let oldProvider = provider
        provider = CodexProvider(configuration: settings.codex, language: settings.language)
        appliedProviderConfiguration = settings.codex
        appliedLanguage = settings.language
        Task { await oldProvider.stop() }
        startRateLimitUpdates()
    }

    private func startRateLimitUpdates() {
        rateLimitUpdateTask?.cancel()
        let provider = self.provider
        rateLimitUpdateTask = Task { [weak self] in
            let stream = await provider.rateLimitUpdates()
            for await _ in stream {
                guard !Task.isCancelled else { break }
                await self?.refreshAll()
            }
        }
    }

    private func startAutoRefresh() {
        autoRefreshTask?.cancel()
        let interval = settings.refreshIntervalSeconds
        autoRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled else { break }
                await self?.refreshAll()
            }
        }
    }

    private func normalized(_ settings: TokenBarSettings) -> TokenBarSettings {
        TokenBarSettings(
            refreshIntervalSeconds: settings.refreshIntervalSeconds,
            notificationsEnabled: settings.notificationsEnabled,
            notificationThresholdPercent: settings.notificationThresholdPercent,
            launchAtLogin: settings.launchAtLogin,
            language: settings.language,
            quotaColors: settings.quotaColors,
            selectedQuota: settings.selectedQuota,
            codex: settings.codex,
            hotKey: settings.hotKey
        )
    }

    private func persistCurrentSettings() {
        settings = normalized(settings)
        do {
            try settingsStore.save(settings)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func resolveConfiguredCodexSource() async {
        let installationResolver = self.installationResolver
        let configuration = settings.codex
        await resolve(
            configuration: configuration,
            preservingAutomaticMode: configuration.installationMode == .automatic
        ) {
            do {
                return try installationResolver.resolve(configuration: configuration)
            } catch CodexInstallationError.sourceMissing {
                return try installationResolver.resolveAutomatically()
            } catch CodexInstallationError.invalidExecutable {
                return try installationResolver.resolveAutomatically()
            }
        }
    }

    private func resolve(
        configuration: CodexProviderConfiguration,
        preservingAutomaticMode: Bool = false,
        operation: @escaping @Sendable () throws -> CodexInstallation
    ) async {
        isResolvingCodexSource = true
        codexInstallationError = nil
        lastError = nil

        let result = await Task.detached(priority: .userInitiated) {
            Result { try operation() }
        }.value

        switch result {
        case .success(let installation):
            var resolvedConfiguration = installation.configuration(
                timeoutSeconds: configuration.timeoutSeconds
            )
            if preservingAutomaticMode {
                resolvedConfiguration.installationMode = .automatic
            }
            settings.codex = resolvedConfiguration
            resolvedInstallation = installation
            codexInstallationError = nil
            persistCurrentSettings()
            rebuildProvider()
            isResolvingCodexSource = false
            await refreshAll()
        case .failure(let error):
            let installationError = (error as? CodexInstallationError) ?? .commandFailed(
                error.localizedDescription
            )
            resolvedInstallation = nil
            codexInstallationError = installationError
            isResolvingCodexSource = false
            let message = installationErrorMessage(installationError)
            updates[.codex] = QuotaProviderUpdate(
                providerID: .codex,
                displayName: "Codex",
                status: installationError == .classicUnsupported ? .unsupported : .error,
                message: message,
                usageURL: URL(string: "https://chatgpt.com/codex/settings/usage")
            )
        }
    }

    private func installationErrorMessage(_ error: CodexInstallationError) -> String {
        switch error {
        case .notFound:
            strings.noCodexSourceDetail
        case .sourceMissing:
            strings.sourceMissing
        case .classicUnsupported:
            strings.unsupportedClassicApp
        case .invalidApplication:
            strings.invalidCodexApp
        case .invalidExecutable:
            strings.invalidCodexCLI
        case .validationTimedOut:
            strings.text(
                "Codex validation timed out. Choose the current ChatGPT/Codex app or CLI.",
                "Codex 验证超时，请选择新版 ChatGPT/Codex 应用或 CLI。"
            )
        case .commandFailed(let message):
            strings.text("Codex validation failed: \(message)", "Codex 验证失败：\(message)")
        }
    }
}
