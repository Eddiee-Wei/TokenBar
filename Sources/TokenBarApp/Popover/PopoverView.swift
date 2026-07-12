import SwiftUI
import TokenBarCore

struct PopoverView: View {
    @ObservedObject var model: TokenBarAppModel
    var openSettings: () -> Void = {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    private var strings: TokenBarStrings { model.strings }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            Rectangle()
                .fill(TokenBarTheme.divider)
                .frame(height: 1)
            if snapshotCount > PopoverLayout.maximumVisibleSnapshots {
                ScrollView {
                    providerList
                }
                .frame(maxHeight: PopoverLayout.maximumListHeight)
            } else {
                providerList
            }
            footer
        }
        .padding(16)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(TokenBarTheme.codexEmerald)
                        .frame(width: 6, height: 6)
                    Text(strings.liveHeader)
                        .font(.caption2.monospaced().weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(headerPercentage)
                        .font(.system(size: 32, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Text(strings.remainingHeader)
                        .font(.caption2.monospaced().weight(.medium))
                        .foregroundStyle(.tertiary)
                }

                Text(summaryText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            Spacer()
            Button {
                Task { await model.refreshAll() }
            } label: {
                Image(systemName: model.isRefreshing ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .frame(width: 30, height: 30)
            .background(TokenBarTheme.surface, in: Circle())
            .overlay {
                Circle().stroke(TokenBarTheme.divider, lineWidth: 1)
            }
            .help(strings.refreshQuotaHelp)
            .tint(TokenBarTheme.codexEmerald)
        }
    }

    private var providerList: some View {
        VStack(spacing: 10) {
            if model.orderedUpdates.isEmpty {
                ContentUnavailableView(
                    strings.connectingCodex,
                    systemImage: "gauge",
                    description: Text(strings.readingLocalQuota)
                )
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(model.orderedUpdates, id: \.providerID) { update in
                    ProviderRow(
                        update: update,
                        strings: strings,
                        quotaColors: model.settings.quotaColors,
                        isSelected: model.isMenuSnapshot,
                        select: model.selectMenuSnapshot,
                        openUsage: { model.openUsagePage(for: update) }
                    )
                }
            }
        }
    }

    private var snapshotCount: Int {
        guard let update = model.updates[.codex] else { return 0 }
        return update.snapshots.isEmpty ? (update.snapshot == nil ? 0 : 1) : update.snapshots.count
    }

    private var footer: some View {
        HStack {
            if let lastError = model.lastError {
                Text(lastError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            } else {
                Text(strings.localOfficial)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(strings.settings) {
                openSettings()
            }
            .buttonStyle(.borderless)
            .tint(TokenBarTheme.codexEmerald)
        }
    }

    private var summaryText: String {
        guard let snapshot = model.menuSnapshot else {
            return strings.waitingForQuota
        }
        let quota = snapshot.quotaLabel ?? snapshot.providerID.defaultDisplayName
        return "\(quota) · \(strings.window(snapshot.windowLabel)) · \(strings.officialLive)"
    }

    private var headerPercentage: String {
        model.menuSnapshot?.remainingPercent.map { "\($0)%" } ?? "--"
    }

}

private struct ProviderRow: View {
    var update: QuotaProviderUpdate
    var strings: TokenBarStrings
    var quotaColors: QuotaColorConfiguration
    var isSelected: (QuotaSnapshot) -> Bool
    var select: (QuotaSnapshot) -> Void
    var openUsage: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(update.displayName)
                        .font(.subheadline.weight(.semibold))
                    Text(strings.text(
                        "QUOTA CHANNELS / \(quotaSnapshots.count) · \(subtitle)",
                        "额度通道 / \(quotaSnapshots.count) · \(subtitle)"
                    ))
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer()
                statusBadge
            }

            if !quotaSnapshots.isEmpty {
                if quotaSnapshots.count == 1, let snapshot = quotaSnapshots.first {
                    quotaWindow(snapshot)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(quotaSnapshots.enumerated()), id: \.offset) { index, snapshot in
                            quotaWindow(snapshot, showWindowLabel: true)
                            if index < quotaSnapshots.count - 1 {
                                Rectangle()
                                    .fill(TokenBarTheme.divider)
                                    .frame(height: 1)
                                    .padding(.vertical, 5)
                            }
                        }
                    }
                }
                if !showsInlineDetails, let detail = providerDetail {
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }
            } else {
                Text(update.message ?? strings.noQuotaSnapshot)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if update.usageURL != nil {
                Button(strings.openUsagePage) {
                    openUsage()
                }
                .buttonStyle(.link)
                .font(.caption)
                .tint(TokenBarTheme.codexEmerald)
            }
        }
        .padding(10)
        .background(
            TokenBarTheme.rowBackground(
                remainingPercent: update.snapshot?.remainingPercent,
                status: update.status
            ),
            in: RoundedRectangle(cornerRadius: 6, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(
                    TokenBarTheme.rowStroke(
                        remainingPercent: update.snapshot?.remainingPercent,
                        status: update.status
                    ),
                    lineWidth: 1
                )
        }
    }

    private var quotaSnapshots: [QuotaSnapshot] {
        update.snapshots.isEmpty ? update.snapshot.map { [$0] } ?? [] : update.snapshots
    }

    private var showsInlineDetails: Bool {
        let details = Set(quotaSnapshots.compactMap(\.detail))
        return details.count > 1 || quotaSnapshots.contains { $0.remainingPercent == nil }
    }

    private var providerDetail: String? {
        quotaSnapshots.compactMap(\.detail).first
    }

    private var hasMultipleQuotaScopes: Bool {
        Set(quotaSnapshots.compactMap(\.quotaLabel)).count > 1
    }

    private var subtitle: String {
        if !quotaSnapshots.isEmpty {
            let source = label(for: update.snapshot?.sourceFreshness ?? quotaSnapshots[0].sourceFreshness)
            let confidence = label(for: update.snapshot?.confidence ?? quotaSnapshots[0].confidence)
            let plan = localizedPlan(update.snapshot?.plan ?? quotaSnapshots[0].plan)
            return ([plan, source, confidence].compactMap { $0 }).joined(separator: " · ")
        }
        return label(for: update.status)
    }

    private func quotaWindow(_ snapshot: QuotaSnapshot, showWindowLabel: Bool = false) -> some View {
        let selected = isSelected(snapshot)
        return Button {
            withAnimation(.easeOut(duration: 0.16)) {
                select(snapshot)
            }
        } label: {
            VStack(spacing: 4) {
                if showWindowLabel {
                    HStack(spacing: 7) {
                        Text(windowTitle(for: snapshot))
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                        Spacer(minLength: 6)
                        if snapshot.resetAt != nil {
                            CountdownText(
                                date: snapshot.resetAt,
                                includesDays: shouldShowDays(for: snapshot),
                                strings: strings
                            )
                        }
                        Image(systemName: selected ? "record.circle.fill" : "circle")
                            .font(.caption2)
                            .foregroundStyle(
                                selected ? TokenBarTheme.codexEmerald : Color.secondary.opacity(0.55)
                            )
                    }
                }

                if snapshot.remainingPercent != nil {
                    QuotaProgressBar(
                        remainingPercent: snapshot.remainingPercent,
                        quotaColors: quotaColors
                    )

                    HStack {
                        Text(strings.remaining(snapshot.remainingPercent ?? 0))
                            .monospacedDigit()
                        Spacer()
                        if !showWindowLabel {
                            CountdownText(
                                date: snapshot.resetAt,
                                includesDays: shouldShowDays(for: snapshot),
                                strings: strings
                            )
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                } else if let detail = snapshot.detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if showsInlineDetails, snapshot.remainingPercent != nil, let detail = snapshot.detail {
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }
            }
            .padding(.leading, 7)
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(TokenBarTheme.codexEmerald)
                    .frame(width: 2, height: 26)
                    .opacity(selected ? 1 : 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(strings.showInMenuBar(windowTitle(for: snapshot)))
    }

    private var statusBadge: some View {
        let statusColor = TokenBarTheme.statusColor(
            status: update.status,
            remainingPercent: update.snapshot?.remainingPercent
        )
        return Text(label(for: update.status))
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(statusColor.opacity(0.16), in: Capsule())
            .foregroundStyle(statusColor)
    }

    private func label(for status: ProviderStatus) -> String {
        strings.status(status)
    }

    private func shouldShowDays(for snapshot: QuotaSnapshot) -> Bool {
        snapshot.windowLabel != "5h"
    }

    private func label(for freshness: SourceFreshness) -> String {
        strings.freshness(freshness)
    }

    private func label(for confidence: SnapshotConfidence) -> String {
        strings.confidence(confidence)
    }

    private func localizedWindow(_ value: String?) -> String {
        strings.window(value)
    }

    private func windowTitle(for snapshot: QuotaSnapshot) -> String {
        let window = localizedWindow(snapshot.windowLabel)
        guard hasMultipleQuotaScopes, let quota = snapshot.quotaLabel else {
            return window
        }
        return "\(quota) · \(window)"
    }

    private func localizedPlan(_ value: String?) -> String? {
        switch value {
        case "free": "Free"
        case "go": "Go"
        case "plus": "Plus"
        case "pro": "Pro"
        case "prolite": "Pro Lite"
        case "team": "Team"
        case "self_serve_business_usage_based", "business": "Business"
        case "enterprise_cbp_usage_based", "enterprise": "Enterprise"
        case "edu": "Edu"
        case "unknown": nil
        case let value?: value
        case nil: nil
        }
    }
}

private struct CountdownText: View {
    var date: Date?
    var includesDays = true
    var strings: TokenBarStrings

    var body: some View {
        TimelineView(.periodic(from: Date(), by: 60)) { timeline in
            Text(Self.text(
                until: date,
                now: timeline.date,
                includesDays: includesDays,
                strings: strings
            ))
                .font(.caption)
                .monospacedDigit()
                .lineLimit(1)
                .foregroundStyle(.secondary)
        }
    }

    private static func text(
        until date: Date?,
        now: Date,
        includesDays: Bool,
        strings: TokenBarStrings
    ) -> String {
        guard let date else { return strings.noResetTime }
        let seconds = date.timeIntervalSince(now)
        guard seconds > 0 else { return strings.reset }

        let totalMinutes = max(1, Int((seconds / 60).rounded(.up)))
        let days = totalMinutes / (24 * 60)
        let hours = (totalMinutes % (24 * 60)) / 60
        let minutes = totalMinutes % 60
        return strings.timeRemaining(
            days: days,
            hours: hours,
            minutes: minutes,
            includesDays: includesDays
        )
    }
}

private struct QuotaProgressBar: View {
    var remainingPercent: Int?
    var quotaColors: QuotaColorConfiguration

    var body: some View {
        GeometryReader { proxy in
            let remaining = QuotaSnapshot.clampPercent(remainingPercent ?? 0)
            let width = proxy.size.width * CGFloat(remaining) / 100
            let color = TokenBarTheme.quotaColor(
                remainingPercent: remainingPercent,
                configuration: quotaColors
            )

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(TokenBarTheme.rail)
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: TokenBarTheme.quotaGradient(
                                remainingPercent: remaining,
                                configuration: quotaColors
                            ),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(remaining == 0 ? 0 : 5, width))
                    .shadow(color: color.opacity(0.16), radius: 2, x: 0, y: 1)
            }
        }
        .frame(height: 7)
    }
}
