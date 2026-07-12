import Foundation

public enum CodexInstallationMode: String, Codable, CaseIterable, Sendable {
    case automatic
    case application
    case customExecutable
}

public struct CodexProviderConfiguration: Codable, Equatable, Sendable {
    public var installationMode: CodexInstallationMode
    public var applicationPath: String?
    public var applicationBundleIdentifier: String?
    public var executable: String
    public var timeoutSeconds: TimeInterval

    public init(
        installationMode: CodexInstallationMode? = nil,
        applicationPath: String? = nil,
        applicationBundleIdentifier: String? = nil,
        executable: String = "codex",
        timeoutSeconds: TimeInterval = 8
    ) {
        let trimmed = executable.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedExecutable = trimmed.isEmpty ? "codex" : trimmed
        let inferredApplicationPath = applicationPath ?? Self.applicationPath(from: normalizedExecutable)
        self.installationMode = installationMode
            ?? (inferredApplicationPath != nil
                ? .application
                : (normalizedExecutable == "codex" ? .automatic : .customExecutable))
        self.applicationPath = inferredApplicationPath
        self.applicationBundleIdentifier = applicationBundleIdentifier
        self.executable = normalizedExecutable
        self.timeoutSeconds = max(2, min(30, timeoutSeconds))
    }

    private enum CodingKeys: String, CodingKey {
        case installationMode
        case applicationPath
        case applicationBundleIdentifier
        case executable
        case timeoutSeconds
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            installationMode: try container.decodeIfPresent(CodexInstallationMode.self, forKey: .installationMode),
            applicationPath: try container.decodeIfPresent(String.self, forKey: .applicationPath),
            applicationBundleIdentifier: try container.decodeIfPresent(String.self, forKey: .applicationBundleIdentifier),
            executable: try container.decodeIfPresent(String.self, forKey: .executable) ?? "codex",
            timeoutSeconds: try container.decodeIfPresent(TimeInterval.self, forKey: .timeoutSeconds) ?? 8
        )
    }

    private static func applicationPath(from executable: String) -> String? {
        guard let appRange = executable.range(of: ".app/Contents/Resources/codex") else { return nil }
        return String(executable[..<appRange.upperBound])
            .replacingOccurrences(of: "/Contents/Resources/codex", with: "")
    }
}

public struct HotKeyConfiguration: Codable, Equatable, Sendable {
    public var isEnabled: Bool
    public var keyCode: UInt16
    public var command: Bool
    public var option: Bool
    public var control: Bool
    public var shift: Bool

    public init(
        isEnabled: Bool = true,
        keyCode: UInt16 = 14,
        command: Bool = true,
        option: Bool = false,
        control: Bool = false,
        shift: Bool = false
    ) {
        self.isEnabled = isEnabled
        self.keyCode = keyCode
        self.command = command
        self.option = option
        self.control = control
        self.shift = shift
    }
}

public struct QuotaColor: Codable, Equatable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = Self.clamp(red)
        self.green = Self.clamp(green)
        self.blue = Self.clamp(blue)
    }

    private enum CodingKeys: String, CodingKey {
        case red
        case green
        case blue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            red: try container.decode(Double.self, forKey: .red),
            green: try container.decode(Double.self, forKey: .green),
            blue: try container.decode(Double.self, forKey: .blue)
        )
    }

    public func interpolatedInLinearLight(to other: QuotaColor, amount: Double) -> QuotaColor {
        let amount = Self.clamp(amount)
        if amount == 0 { return self }
        if amount == 1 { return other }
        return QuotaColor(
            red: Self.linearToSRGB(Self.mix(Self.srgbToLinear(red), Self.srgbToLinear(other.red), amount)),
            green: Self.linearToSRGB(Self.mix(Self.srgbToLinear(green), Self.srgbToLinear(other.green), amount)),
            blue: Self.linearToSRGB(Self.mix(Self.srgbToLinear(blue), Self.srgbToLinear(other.blue), amount))
        )
    }

    private static func clamp(_ value: Double) -> Double {
        min(1, max(0, value))
    }

    private static func mix(_ start: Double, _ end: Double, _ amount: Double) -> Double {
        start + (end - start) * amount
    }

    private static func srgbToLinear(_ value: Double) -> Double {
        value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
    }

    private static func linearToSRGB(_ value: Double) -> Double {
        value <= 0.0031308 ? value * 12.92 : 1.055 * pow(value, 1 / 2.4) - 0.055
    }
}

public struct QuotaColorConfiguration: Codable, Equatable, Sendable {
    public static let defaultAbundant = QuotaColor(red: 0.06, green: 0.54, blue: 0.40)
    public static let defaultDepleted = QuotaColor(red: 0.70, green: 0.16, blue: 0.13)

    public var abundant: QuotaColor
    public var depleted: QuotaColor

    public init(
        abundant: QuotaColor = Self.defaultAbundant,
        depleted: QuotaColor = Self.defaultDepleted
    ) {
        self.abundant = abundant
        self.depleted = depleted
    }

    public func color(forRemainingPercent remainingPercent: Int) -> QuotaColor {
        let amount = Double(QuotaSnapshot.clampPercent(remainingPercent)) / 100
        return color(forAmount: amount)
    }

    public func gradient(forRemainingPercent remainingPercent: Int) -> [QuotaColor] {
        let amount = Double(QuotaSnapshot.clampPercent(remainingPercent)) / 100
        let leadingAmount = min(1, amount + 0.18)
        return (0...4).map { index in
            let progress = Double(index) / 4
            return color(forAmount: leadingAmount + (amount - leadingAmount) * progress)
        }
    }

    private func color(forAmount amount: Double) -> QuotaColor {
        depleted.interpolatedInLinearLight(to: abundant, amount: amount)
    }
}

public struct TokenBarSettings: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 5

    public var schemaVersion: Int
    public var refreshIntervalSeconds: TimeInterval
    public var notificationsEnabled: Bool
    public var notificationThresholdPercent: Int
    public var launchAtLogin: Bool
    public var language: AppLanguage
    public var quotaColors: QuotaColorConfiguration
    public var selectedQuota: QuotaSelection?
    public var codex: CodexProviderConfiguration
    public var hotKey: HotKeyConfiguration

    public init(
        schemaVersion: Int = Self.currentSchemaVersion,
        refreshIntervalSeconds: TimeInterval = 300,
        notificationsEnabled: Bool = false,
        notificationThresholdPercent: Int = 20,
        launchAtLogin: Bool = false,
        language: AppLanguage = .english,
        quotaColors: QuotaColorConfiguration = QuotaColorConfiguration(),
        selectedQuota: QuotaSelection? = nil,
        codex: CodexProviderConfiguration = CodexProviderConfiguration(),
        hotKey: HotKeyConfiguration = HotKeyConfiguration()
    ) {
        self.schemaVersion = schemaVersion
        self.refreshIntervalSeconds = max(60, min(3600, refreshIntervalSeconds))
        self.notificationsEnabled = notificationsEnabled
        self.notificationThresholdPercent = QuotaSnapshot.clampPercent(notificationThresholdPercent)
        self.launchAtLogin = launchAtLogin
        self.language = language
        self.quotaColors = quotaColors
        self.selectedQuota = selectedQuota
        self.codex = codex
        self.hotKey = hotKey
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case refreshIntervalSeconds
        case notificationsEnabled
        case notificationThresholdPercent
        case launchAtLogin
        case language
        case quotaColors
        case selectedQuota
        case codex
        case hotKey
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            schemaVersion: try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? Self.currentSchemaVersion,
            refreshIntervalSeconds: try container.decodeIfPresent(TimeInterval.self, forKey: .refreshIntervalSeconds) ?? 300,
            notificationsEnabled: try container.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? false,
            notificationThresholdPercent: try container.decodeIfPresent(Int.self, forKey: .notificationThresholdPercent) ?? 20,
            launchAtLogin: try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false,
            language: try container.decodeIfPresent(AppLanguage.self, forKey: .language) ?? .english,
            quotaColors: try container.decodeIfPresent(QuotaColorConfiguration.self, forKey: .quotaColors) ?? QuotaColorConfiguration(),
            selectedQuota: try container.decodeIfPresent(QuotaSelection.self, forKey: .selectedQuota),
            codex: try container.decodeIfPresent(CodexProviderConfiguration.self, forKey: .codex) ?? CodexProviderConfiguration(),
            hotKey: try container.decodeIfPresent(HotKeyConfiguration.self, forKey: .hotKey) ?? HotKeyConfiguration()
        )
        schemaVersion = Self.currentSchemaVersion
    }
}
