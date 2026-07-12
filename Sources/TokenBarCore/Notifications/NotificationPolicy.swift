import Foundation

public struct NotificationPolicy: Equatable, Sendable {
    public var thresholdPercent: Int

    public init(thresholdPercent: Int) {
        self.thresholdPercent = QuotaSnapshot.clampPercent(thresholdPercent)
    }

    public func shouldNotify(previous: QuotaSnapshot?, current: QuotaSnapshot) -> Bool {
        guard let remaining = current.remainingPercent else { return false }
        if remaining > thresholdPercent { return false }
        guard let previousRemaining = previous?.remainingPercent else { return true }
        return previousRemaining > thresholdPercent
    }
}
