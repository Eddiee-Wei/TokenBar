import Foundation
import TokenBarCore
@preconcurrency import UserNotifications

actor QuotaNotificationService {
    private let center: UNUserNotificationCenter?
    private let defaults: UserDefaults
    private let defaultsKey = "notifiedQuotaWindows"

    init(
        center: UNUserNotificationCenter? = nil,
        defaults: UserDefaults = .standard
    ) {
        if let center {
            self.center = center
        } else if Bundle.main.bundleURL.pathExtension == "app" {
            self.center = .current()
        } else {
            self.center = nil
        }
        self.defaults = defaults
    }

    func requestAuthorization() async -> Bool {
        do {
            guard let center else { return false }
            return try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    func evaluate(
        previous: QuotaProviderUpdate?,
        current: QuotaProviderUpdate,
        thresholdPercent: Int,
        language: AppLanguage = .english
    ) async {
        let strings = TokenBarStrings(language)
        let policy = NotificationPolicy(thresholdPercent: thresholdPercent)
        guard let center else { return }
        let previousSnapshots = snapshots(in: previous)
        var notifiedKeys = Set(defaults.stringArray(forKey: defaultsKey) ?? [])
        var validKeys = Set<String>()

        for snapshot in snapshots(in: current) {
            let key = notificationKey(for: snapshot)
            validKeys.insert(key)
            let matchingPreviousSnapshot = previousSnapshots.first {
                $0.windowLabel == snapshot.windowLabel && $0.quotaLabel == snapshot.quotaLabel
            }
            let previousSnapshot = matchingPreviousSnapshot.flatMap {
                notificationKey(for: $0) == key ? $0 : nil
            }
            guard policy.shouldNotify(previous: previousSnapshot, current: snapshot) else { continue }
            guard !notifiedKeys.contains(key) else { continue }
            guard let remaining = snapshot.remainingPercent else { continue }

            let content = UNMutableNotificationContent()
            content.title = strings.quotaAlertTitle
            content.body = strings.quotaAlertBody(
                name: strings.quotaDisplayName(
                    quota: snapshot.quotaLabel,
                    window: snapshot.windowLabel
                ),
                remaining: remaining
            )
            content.sound = .default
            do {
                try await center.add(UNNotificationRequest(
                    identifier: "tokenbar.\(key)",
                    content: content,
                    trigger: nil
                ))
                notifiedKeys.insert(key)
            } catch {
                continue
            }
        }

        notifiedKeys.formIntersection(validKeys)
        defaults.set(Array(notifiedKeys).sorted(), forKey: defaultsKey)
    }

    private func snapshots(in update: QuotaProviderUpdate?) -> [QuotaSnapshot] {
        guard let update else { return [] }
        return update.snapshots.isEmpty ? update.snapshot.map { [$0] } ?? [] : update.snapshots
    }

    private func notificationKey(for snapshot: QuotaSnapshot) -> String {
        let reset = snapshot.resetAt.map { String(Int($0.timeIntervalSince1970)) } ?? "unknown"
        return [snapshot.quotaLabel ?? "codex", snapshot.windowLabel ?? "quota", reset]
            .joined(separator: ".")
            .replacingOccurrences(of: " ", with: "-")
    }

}
