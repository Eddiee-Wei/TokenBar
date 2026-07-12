import Foundation
import Testing
@testable import TokenBarCore

@Suite("Codex rate-limit parsing")
struct CodexRateLimitParserTests {
    @Test("Parses every official quota bucket and window")
    func parsesMultiBucketResponse() throws {
        let response = try JSONDecoder().decode(CodexRateLimitResponse.self, from: Data(Self.fixture.utf8))
        let snapshots = CodexRateLimitParser.snapshots(from: response)

        #expect(snapshots.count == 4)
        #expect(snapshots.map(\.windowLabel) == ["5h", "7d", "5h", "7d"])
        #expect(snapshots.map(\.quotaLabel) == [
            "Codex", "Codex", "GPT-5.3-Codex-Spark", "GPT-5.3-Codex-Spark"
        ])
        #expect(CodexRateLimitParser.tightestSnapshot(in: snapshots)?.remainingPercent == 30)
        #expect(snapshots[0].detail?.contains("2 quota resets") == true)

        let chineseSnapshots = CodexRateLimitParser.snapshots(
            from: response,
            language: .simplifiedChinese
        )
        #expect(chineseSnapshots[0].detail?.contains("2 次额度重置") == true)
    }

    @Test("Menu bar prefers the seven-day Codex quota")
    func prefersSevenDayWindow() throws {
        let response = try JSONDecoder().decode(CodexRateLimitResponse.self, from: Data(Self.fixture.utf8))
        let update = QuotaProviderUpdate(
            providerID: .codex,
            displayName: "Codex",
            status: .ok,
            snapshots: CodexRateLimitParser.snapshots(from: response)
        )
        #expect(QuotaSummary.preferredSnapshot(from: [update])?.windowLabel == "7d")
        #expect(QuotaSummary.menuTitle(from: [update]) == "30%")
    }

    @Test("Menu bar follows a selected quota window and falls back safely")
    func followsSelectedQuotaWindow() throws {
        let response = try JSONDecoder().decode(CodexRateLimitResponse.self, from: Data(Self.fixture.utf8))
        let update = QuotaProviderUpdate(
            providerID: .codex,
            displayName: "Codex",
            status: .ok,
            snapshots: CodexRateLimitParser.snapshots(from: response)
        )
        let sparkFiveHour = QuotaSelection(
            quotaLabel: "GPT-5.3-Codex-Spark",
            windowLabel: "5h"
        )
        let missing = QuotaSelection(quotaLabel: "Missing", windowLabel: "5h")

        #expect(
            QuotaSummary.selectedSnapshot(from: [update], selection: sparkFiveHour)?.quotaLabel
                == "GPT-5.3-Codex-Spark"
        )
        #expect(QuotaSummary.menuTitle(from: [update], selection: sparkFiveHour) == "100%")
        #expect(QuotaSummary.menuTitle(from: [update], selection: missing) == "30%")
    }

    @Test("Maps explicit server limits")
    func mapsReachedLimit() throws {
        let data = Data("""
        {"rateLimits":{"rateLimitReachedType":"workspace_member_credits_depleted","primary":{"usedPercent":40,"windowDurationMins":300}}}
        """.utf8)
        let response = try JSONDecoder().decode(CodexRateLimitResponse.self, from: data)
        #expect(CodexRateLimitParser.isLimited(response))
        #expect(CodexRateLimitParser.snapshot(from: response)?.detail?.contains("Member credits depleted") == true)
        #expect(
            CodexRateLimitParser.snapshot(from: response, language: .simplifiedChinese)?
                .detail?.contains("成员 credits 已用完") == true
        )
    }

    private static let fixture = """
    {
      "rateLimitResetCredits": { "availableCount": 2, "credits": null },
      "rateLimits": {"planType":"pro","primary":{"usedPercent":10,"windowDurationMins":300}},
      "rateLimitsByLimitId": {
        "codex": {
          "limitId":"codex","limitName":"Codex","planType":"pro",
          "primary":{"usedPercent":40,"windowDurationMins":300,"resetsAt":1800000000},
          "secondary":{"usedPercent":70,"windowDurationMins":10080,"resetsAt":1800100000},
          "credits":{"balance":"12.00","hasCredits":true,"unlimited":false}
        },
        "codex_spark": {
          "limitId":"codex_spark","limitName":"GPT-5.3-Codex-Spark","planType":"pro",
          "primary":{"usedPercent":0,"windowDurationMins":300,"resetsAt":1800000000},
          "secondary":{"usedPercent":0,"windowDurationMins":10080,"resetsAt":1800100000}
        }
      }
    }
    """
}
