import Foundation

public enum ProviderID: String, Codable, CaseIterable, Identifiable, Sendable {
    case codex

    public var id: String { rawValue }
    public var defaultDisplayName: String { "Codex" }
}

public enum ProviderCapability: String, Codable, CaseIterable, Sendable {
    case liveRateLimit
    case usageHistory
    case dashboardDeepLink
}

public enum ProviderStatus: String, Codable, Sendable {
    case ok
    case stale
    case limited
    case unauthorized
    case unsupported
    case error
    case disabled
}

public enum ProviderAuthStatus: String, Codable, Sendable {
    case configured
    case missingCredentials
    case signedOut
    case unsupported
    case unknown
}

public enum SourceFreshness: String, Codable, Sendable {
    case live
    case cached
    case unavailable
}

public enum SnapshotConfidence: String, Codable, Sendable {
    case high
    case medium
    case low
}

public enum QuotaSeverity: String, Codable, Sendable {
    case healthy
    case warning
    case critical
    case unknown

    public static func from(remainingPercent: Int?) -> QuotaSeverity {
        guard let remainingPercent else { return .unknown }
        if remainingPercent < 20 { return .critical }
        if remainingPercent <= 50 { return .warning }
        return .healthy
    }
}

public struct ProviderDescriptor: Codable, Equatable, Sendable {
    public var id: ProviderID
    public var displayName: String
    public var capabilities: [ProviderCapability]
    public var usageURL: URL?

    public init(
        id: ProviderID,
        displayName: String? = nil,
        capabilities: [ProviderCapability],
        usageURL: URL? = nil
    ) {
        self.id = id
        self.displayName = displayName ?? id.defaultDisplayName
        self.capabilities = capabilities
        self.usageURL = usageURL
    }
}

public struct QuotaSnapshot: Codable, Equatable, Sendable {
    public var providerID: ProviderID
    public var usedPercent: Int?
    public var remainingPercent: Int?
    public var resetAt: Date?
    public var windowLabel: String?
    public var quotaLabel: String?
    public var plan: String?
    public var sourceFreshness: SourceFreshness
    public var confidence: SnapshotConfidence
    public var detail: String?
    public var updatedAt: Date

    public init(
        providerID: ProviderID,
        usedPercent: Int?,
        remainingPercent: Int? = nil,
        resetAt: Date? = nil,
        windowLabel: String? = nil,
        quotaLabel: String? = nil,
        plan: String? = nil,
        sourceFreshness: SourceFreshness,
        confidence: SnapshotConfidence,
        detail: String? = nil,
        updatedAt: Date = Date()
    ) {
        let normalizedUsed = usedPercent.map(Self.clampPercent)
        let normalizedRemaining = remainingPercent.map(Self.clampPercent)
        self.providerID = providerID
        self.usedPercent = normalizedUsed
        self.remainingPercent = normalizedRemaining ?? normalizedUsed.map { Self.clampPercent(100 - $0) }
        self.resetAt = resetAt
        self.windowLabel = windowLabel
        self.quotaLabel = quotaLabel
        self.plan = plan
        self.sourceFreshness = sourceFreshness
        self.confidence = confidence
        self.detail = detail
        self.updatedAt = updatedAt
    }

    public var severity: QuotaSeverity {
        QuotaSeverity.from(remainingPercent: remainingPercent)
    }

    public static func clampPercent(_ value: Int) -> Int {
        min(100, max(0, value))
    }

    public static func roundedPercent(_ value: Double) -> Int {
        clampPercent(Int(value.rounded()))
    }
}

public struct QuotaSelection: Codable, Equatable, Sendable {
    public var quotaLabel: String?
    public var windowLabel: String?

    public init(quotaLabel: String?, windowLabel: String?) {
        self.quotaLabel = quotaLabel
        self.windowLabel = windowLabel
    }

    public init(snapshot: QuotaSnapshot) {
        self.init(quotaLabel: snapshot.quotaLabel, windowLabel: snapshot.windowLabel)
    }

    public func matches(_ snapshot: QuotaSnapshot) -> Bool {
        quotaLabel == snapshot.quotaLabel && windowLabel == snapshot.windowLabel
    }
}

public struct QuotaProviderUpdate: Codable, Equatable, Sendable {
    public var providerID: ProviderID
    public var displayName: String
    public var status: ProviderStatus
    public var snapshot: QuotaSnapshot?
    public var snapshots: [QuotaSnapshot]
    public var message: String?
    public var usageURL: URL?
    public var refreshedAt: Date

    public init(
        providerID: ProviderID,
        displayName: String,
        status: ProviderStatus,
        snapshot: QuotaSnapshot? = nil,
        snapshots: [QuotaSnapshot] = [],
        message: String? = nil,
        usageURL: URL? = nil,
        refreshedAt: Date = Date()
    ) {
        let allSnapshots = snapshots.isEmpty ? snapshot.map { [$0] } ?? [] : snapshots
        self.providerID = providerID
        self.displayName = displayName
        self.status = status
        self.snapshot = snapshot ?? Self.tightestSnapshot(in: allSnapshots)
        self.snapshots = allSnapshots
        self.message = message
        self.usageURL = usageURL
        self.refreshedAt = refreshedAt
    }

    private static func tightestSnapshot(in snapshots: [QuotaSnapshot]) -> QuotaSnapshot? {
        snapshots
            .filter { $0.remainingPercent != nil }
            .min { ($0.remainingPercent ?? 101) < ($1.remainingPercent ?? 101) }
            ?? snapshots.first
    }
}

public enum ProviderError: Error, Equatable, Sendable {
    case missingCredentials
    case unauthorized
    case forbidden
    case rateLimited(retryAfterSeconds: Int?)
    case unsupported(String)
    case unavailable(String)
    case invalidResponse(String)
    case commandFailed(String)

    public var status: ProviderStatus {
        switch self {
        case .missingCredentials, .unauthorized:
            .unauthorized
        case .forbidden:
            .unauthorized
        case .unsupported:
            .unsupported
        case .rateLimited:
            .limited
        case .unavailable, .invalidResponse, .commandFailed:
            .error
        }
    }

    public var userMessage: String { userMessage(language: .english) }

    public func userMessage(language: AppLanguage) -> String {
        let strings = TokenBarStrings(language)
        switch self {
        case .missingCredentials:
            return strings.text("Credentials are missing.", "缺少凭据。")
        case .unauthorized:
            return strings.text("Authentication failed.", "认证失败。")
        case .forbidden:
            return strings.text("The current account does not have access.", "当前凭据没有访问权限。")
        case .rateLimited(let retryAfterSeconds):
            return retryAfterSeconds.map {
                strings.text("Rate limited. Retry in \($0) seconds.", "触发频率限制，\($0) 秒后重试。")
            } ?? strings.text("Rate limited.", "触发频率限制。")
        case .unsupported(let reason):
            return reason
        case .unavailable(let reason):
            return reason
        case .invalidResponse(let reason):
            return strings.text("Invalid response: \(reason)", "响应格式异常：\(reason)")
        case .commandFailed(let reason):
            return reason
        }
    }
}
