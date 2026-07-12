import Foundation

public enum CodexRateLimitParser {
    public static func snapshots(
        from response: CodexRateLimitResponse,
        now: Date = Date(),
        language: AppLanguage = .english
    ) -> [QuotaSnapshot] {
        let strings = TokenBarStrings(language)
        let candidates = rateLimitCandidates(from: response)
        let windowSnapshots = candidates.enumerated().flatMap { index, candidate in
            [candidate.snapshot.primary, candidate.snapshot.secondary]
                .compactMap { $0 }
                .sorted { ($0.windowDurationMins ?? 0) < ($1.windowDurationMins ?? 0) }
                .map { window in
                    QuotaSnapshot(
                        providerID: .codex,
                        usedPercent: window.usedPercent,
                        resetAt: window.resetsAt.map { Date(timeIntervalSince1970: TimeInterval($0)) },
                        windowLabel: label(for: window.windowDurationMins),
                        quotaLabel: quotaLabel(for: candidate.id, snapshot: candidate.snapshot),
                        plan: candidate.snapshot.planType,
                        sourceFreshness: .live,
                        confidence: .high,
                        detail: detail(
                            for: candidate.snapshot,
                            resetCredits: index == 0 ? response.rateLimitResetCredits : nil,
                            strings: strings
                        ),
                        updatedAt: now
                    )
                }
        }

        if !windowSnapshots.isEmpty {
            return windowSnapshots
        }

        if let candidate = candidates.first(where: { $0.snapshot.individualLimit != nil }),
           let individualLimit = candidate.snapshot.individualLimit {
            return [
                QuotaSnapshot(
                    providerID: .codex,
                    usedPercent: 100 - individualLimit.remainingPercent,
                    remainingPercent: individualLimit.remainingPercent,
                    resetAt: Date(timeIntervalSince1970: TimeInterval(individualLimit.resetsAt)),
                    windowLabel: "spend",
                    quotaLabel: quotaLabel(for: candidate.id, snapshot: candidate.snapshot),
                    plan: candidate.snapshot.planType,
                    sourceFreshness: .live,
                    confidence: .high,
                    detail: strings.text(
                        "Used \(individualLimit.used) / \(individualLimit.limit)",
                        "已用 \(individualLimit.used) / \(individualLimit.limit)"
                    ),
                    updatedAt: now
                )
            ]
        }

        return []
    }

    public static func isLimited(_ response: CodexRateLimitResponse) -> Bool {
        rateLimitCandidates(from: response).contains { candidate in
            candidate.snapshot.rateLimitReachedType != nil
                || candidate.snapshot.primary?.usedPercent == 100
                || candidate.snapshot.secondary?.usedPercent == 100
                || candidate.snapshot.individualLimit?.remainingPercent == 0
        }
    }

    public static func snapshot(
        from response: CodexRateLimitResponse,
        now: Date = Date(),
        language: AppLanguage = .english
    ) -> QuotaSnapshot? {
        tightestSnapshot(in: snapshots(from: response, now: now, language: language))
    }

    public static func tightestSnapshot(in snapshots: [QuotaSnapshot]) -> QuotaSnapshot? {
        snapshots
            .filter { $0.remainingPercent != nil }
            .min { ($0.remainingPercent ?? 101) < ($1.remainingPercent ?? 101) }
            ?? snapshots.first
    }

    private static func label(for minutes: Int64?) -> String? {
        guard let minutes else { return nil }
        return switch minutes {
        case 300: "5h"
        case 1_440: "24h"
        case 10_080: "7d"
        default:
            if minutes % 1_440 == 0 { "\(minutes / 1_440)d" }
            else if minutes % 60 == 0 { "\(minutes / 60)h" }
            else { "\(minutes)m" }
        }
    }

    private static func detail(
        for snapshot: CodexRateLimitSnapshot,
        resetCredits: CodexRateLimitResetCreditsSummary?,
        strings: TokenBarStrings
    ) -> String? {
        var parts = strings.additionalCredits(
            balance: snapshot.credits?.balance,
            unlimited: snapshot.credits?.unlimited == true,
            resetCount: resetCredits.flatMap {
                $0.availableCount > 0 ? Int(clamping: $0.availableCount) : nil
            }
        ).map { [$0] } ?? []
        if let reached = snapshot.rateLimitReachedType {
            parts.append(strings.reachedLimitReason(reached) ?? reached)
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private static func rateLimitCandidates(
        from response: CodexRateLimitResponse
    ) -> [(id: String?, snapshot: CodexRateLimitSnapshot)] {
        guard let buckets = response.rateLimitsByLimitId, !buckets.isEmpty else {
            return [(response.rateLimits.limitId, response.rateLimits)]
        }

        return buckets
            .sorted { lhs, rhs in
                if lhs.key == "codex" { return true }
                if rhs.key == "codex" { return false }
                return lhs.key.localizedStandardCompare(rhs.key) == .orderedAscending
            }
            .map { (id: $0.key, snapshot: $0.value) }
    }

    private static func quotaLabel(for id: String?, snapshot: CodexRateLimitSnapshot) -> String? {
        if let name = snapshot.limitName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            return name
        }
        if id == "codex" {
            return "Codex"
        }
        return id
    }

}
