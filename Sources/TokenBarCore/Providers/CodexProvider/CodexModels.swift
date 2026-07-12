import Foundation

public struct CodexRPCError: Decodable, Equatable, Sendable {
    public var code: Int
    public var message: String
}

public struct CodexRPCResponse<Result: Decodable & Equatable & Sendable>: Decodable, Equatable, Sendable {
    public var id: Int?
    public var result: Result?
    public var error: CodexRPCError?
}

public struct CodexRPCAcknowledgement: Decodable, Sendable {
    public var id: Int?
    public var result: EmptyJSONObject?
    public var error: CodexRPCError?
}

public struct EmptyJSONObject: Decodable, Sendable {}

public struct CodexCreditsSnapshot: Decodable, Equatable, Sendable {
    public var balance: String?
    public var hasCredits: Bool
    public var unlimited: Bool
}

public struct CodexRateLimitWindow: Decodable, Equatable, Sendable {
    public var resetsAt: Int64?
    public var usedPercent: Int
    public var windowDurationMins: Int64?
}

public struct CodexSpendControlLimitSnapshot: Decodable, Equatable, Sendable {
    public var limit: String
    public var remainingPercent: Int
    public var resetsAt: Int64
    public var used: String
}

public struct CodexRateLimitSnapshot: Decodable, Equatable, Sendable {
    public var credits: CodexCreditsSnapshot?
    public var individualLimit: CodexSpendControlLimitSnapshot?
    public var limitId: String?
    public var limitName: String?
    public var planType: String?
    public var primary: CodexRateLimitWindow?
    public var rateLimitReachedType: String?
    public var secondary: CodexRateLimitWindow?
}

public struct CodexRateLimitResetCreditsSummary: Decodable, Equatable, Sendable {
    public var availableCount: Int64
    public var credits: [CodexRateLimitResetCredit]?
}

public struct CodexRateLimitResetCredit: Decodable, Equatable, Sendable {
    public var description: String?
    public var expiresAt: Int64?
    public var grantedAt: Int64
    public var id: String
    public var resetType: String
    public var status: String
    public var title: String?
}

public struct CodexRateLimitResponse: Decodable, Equatable, Sendable {
    public var rateLimitResetCredits: CodexRateLimitResetCreditsSummary?
    public var rateLimits: CodexRateLimitSnapshot
    public var rateLimitsByLimitId: [String: CodexRateLimitSnapshot]?
}

public struct CodexUsageDailyBucket: Decodable, Equatable, Sendable {
    public var startDate: String
    public var tokens: Int64
}

public struct CodexUsageSummary: Decodable, Equatable, Sendable {
    public var currentStreakDays: Int64?
    public var lifetimeTokens: Int64?
    public var longestRunningTurnSec: Int64?
    public var longestStreakDays: Int64?
    public var peakDailyTokens: Int64?
}

public struct CodexUsageResponse: Decodable, Equatable, Sendable {
    public var dailyUsageBuckets: [CodexUsageDailyBucket]?
    public var summary: CodexUsageSummary
}
