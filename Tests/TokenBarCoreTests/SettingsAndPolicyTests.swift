import Foundation
import Testing
@testable import TokenBarCore

@Suite("Settings and quota policy")
struct SettingsAndPolicyTests {
    @Test("Legacy settings migrate to Codex-only schema")
    func migratesLegacySettings() throws {
        let data = Data("""
        {
          "enabledProviders":["codex","claudeCode","cursor","customScript"],
          "refreshIntervalSeconds":120,
          "notificationThresholdPercent":15,
          "codex":{"executable":"/usr/local/bin/codex","timeoutSeconds":12},
          "cursor":{"mode":"personalManual"},
          "hotKey":{"isEnabled":true,"keyCode":14,"command":true,"option":false,"control":false,"shift":false}
        }
        """.utf8)
        let settings = try JSONDecoder().decode(TokenBarSettings.self, from: data)

        #expect(settings.schemaVersion == TokenBarSettings.currentSchemaVersion)
        #expect(settings.refreshIntervalSeconds == 120)
        #expect(settings.codex.executable == "/usr/local/bin/codex")
        #expect(settings.codex.installationMode == .customExecutable)
        #expect(settings.codex.timeoutSeconds == 12)
        #expect(settings.language == .english)
        #expect(!settings.notificationsEnabled)
        #expect(settings.quotaColors == QuotaColorConfiguration())
        #expect(settings.selectedQuota == nil)
    }

    @Test("Settings atomically replace the prior file")
    func savesAndReplacesSettings() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "TokenBarTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = JSONSettingsStore(url: directory.appending(path: "settings.json"))

        let colors = QuotaColorConfiguration(
            abundant: QuotaColor(red: 0.2, green: 0.8, blue: 0.4),
            depleted: QuotaColor(red: 0.9, green: 0.1, blue: 0.2)
        )
        let selectedQuota = QuotaSelection(quotaLabel: "Codex", windowLabel: "5h")
        try store.save(TokenBarSettings(refreshIntervalSeconds: 60))
        try store.save(
            TokenBarSettings(
                refreshIntervalSeconds: 900,
                notificationsEnabled: true,
                language: .simplifiedChinese,
                quotaColors: colors,
                selectedQuota: selectedQuota
            )
        )
        let loaded = try store.load()
        let files = try FileManager.default.contentsOfDirectory(atPath: directory.path)

        #expect(loaded.refreshIntervalSeconds == 900)
        #expect(loaded.notificationsEnabled)
        #expect(loaded.language == .simplifiedChinese)
        #expect(loaded.quotaColors == colors)
        #expect(loaded.selectedQuota == selectedQuota)
        #expect(files == ["settings.json"])
    }

    @Test("Bundled Codex paths migrate to an application source")
    func migratesBundledApplicationPath() {
        let configuration = CodexProviderConfiguration(
            executable: "/Applications/ChatGPT.app/Contents/Resources/codex"
        )

        #expect(configuration.installationMode == .application)
        #expect(configuration.applicationPath == "/Applications/ChatGPT.app")
    }

    @Test("English is the product default and Chinese remains selectable")
    func localizesProductStrings() {
        #expect(TokenBarSettings().language == .english)
        #expect(TokenBarStrings(.english).settings == "Settings")
        #expect(TokenBarStrings(.simplifiedChinese).settings == "设置")
        #expect(TokenBarStrings(.english).window("7d") == "7 days")
        #expect(TokenBarStrings(.simplifiedChinese).window("7d") == "7 天")
    }

    @Test("Notification policy fires once at threshold crossing")
    func notificationThresholdCrossing() {
        let policy = NotificationPolicy(thresholdPercent: 20)
        let healthy = QuotaSnapshot(providerID: .codex, usedPercent: 70, sourceFreshness: .live, confidence: .high)
        let critical = QuotaSnapshot(providerID: .codex, usedPercent: 85, sourceFreshness: .live, confidence: .high)
        #expect(policy.shouldNotify(previous: nil, current: critical))
        #expect(policy.shouldNotify(previous: healthy, current: critical))
        #expect(!policy.shouldNotify(previous: critical, current: critical))
    }

    @Test("Quota percentages are normalized")
    func normalizesPercentages() {
        #expect(QuotaSnapshot.clampPercent(-4) == 0)
        #expect(QuotaSnapshot.clampPercent(104) == 100)
        #expect(QuotaSnapshot.roundedPercent(49.6) == 50)
    }

    @Test("Quota colors interpolate in linear light")
    func interpolatesQuotaColors() {
        let configuration = QuotaColorConfiguration(
            abundant: QuotaColor(red: 1, green: 1, blue: 1),
            depleted: QuotaColor(red: 0, green: 0, blue: 0)
        )

        #expect(configuration.color(forRemainingPercent: 0) == configuration.depleted)
        #expect(configuration.color(forRemainingPercent: 100) == configuration.abundant)
        #expect(configuration.color(forRemainingPercent: 50).red > 0.7)

        let gradient = configuration.gradient(forRemainingPercent: 40)
        #expect(gradient.count == 5)
        #expect((gradient.first?.red ?? 0) > (gradient.last?.red ?? 1))
    }
}
