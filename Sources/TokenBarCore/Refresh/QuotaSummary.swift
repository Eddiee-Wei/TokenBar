import Foundation

public enum QuotaSummary {
    public static func tightestSnapshot(from updates: [QuotaProviderUpdate]) -> QuotaSnapshot? {
        snapshots(from: updates)
            .filter { $0.remainingPercent != nil }
            .min { ($0.remainingPercent ?? 101) < ($1.remainingPercent ?? 101) }
    }

    public static func preferredSnapshot(from updates: [QuotaProviderUpdate]) -> QuotaSnapshot? {
        let availableSnapshots = snapshots(from: updates)
            .filter { $0.remainingPercent != nil }

        if let sevenDay = availableSnapshots
            .filter({ $0.windowLabel == "7d" })
            .min(by: { ($0.remainingPercent ?? 101) < ($1.remainingPercent ?? 101) }) {
            return sevenDay
        }

        return tightestSnapshot(from: updates)
    }

    public static func selectedSnapshot(
        from updates: [QuotaProviderUpdate],
        selection: QuotaSelection?
    ) -> QuotaSnapshot? {
        guard let selection else { return preferredSnapshot(from: updates) }
        return snapshots(from: updates).first(where: selection.matches)
            ?? preferredSnapshot(from: updates)
    }

    public static func menuTitle(
        from updates: [QuotaProviderUpdate],
        selection: QuotaSelection? = nil
    ) -> String {
        guard
            let snapshot = selectedSnapshot(from: updates, selection: selection),
            let remaining = snapshot.remainingPercent
        else {
            return "TokenBar"
        }
        return "\(remaining)%"
    }

    private static func snapshots(from updates: [QuotaProviderUpdate]) -> [QuotaSnapshot] {
        updates.flatMap { update in
            update.snapshots.isEmpty ? update.snapshot.map { [$0] } ?? [] : update.snapshots
        }
    }
}
