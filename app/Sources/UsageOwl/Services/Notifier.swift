import Foundation
import UserNotifications

/// Fires local notifications when a quota window crosses 25/50/75/90%.
/// Each threshold fires once per window; tracking re-arms when the window resets.
final class Notifier: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let shared = Notifier()

    private let queue = DispatchQueue(label: "app.usageowl.notifier")
    private var fired: [String: Set<Int>] = [:]
    private var resetMarkers: [String: Date] = [:]
    private var monthMarkers: [String: String] = [:]

    /// Spend alerts start at 50%: crossing a quarter of a monthly money cap is
    /// routine, and this is the one alert that shouldn't cry wolf.
    private static let spendThresholds = [50, 75, 90]

    /// UserNotifications requires a real app bundle; skip when run as a bare binary.
    private var bundled: Bool { Bundle.main.bundleIdentifier != nil }

    func requestAuthorization() {
        guard bundled else { return }
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func check(snapshot: UsageSnapshot) {
        guard bundled, snapshot.error == nil else { return }
        queue.async {
            for window in snapshot.windows {
                let key = "\(snapshot.id).\(window.label)"
                if let reset = window.resetDate {
                    if let marker = self.resetMarkers[key], abs(marker.timeIntervalSince(reset)) > 1 {
                        self.fired[key] = []  // new period — re-arm alerts
                    }
                    self.resetMarkers[key] = reset
                }
                for threshold in [25, 50, 75, 90] where window.usedPercent >= Double(threshold) {
                    guard self.fired[key, default: []].contains(threshold) == false else { continue }
                    self.fired[key, default: []].insert(threshold)
                    self.deliver(snapshot: snapshot, window: window, threshold: threshold)
                }
            }
            self.checkSpend(snapshot)
        }
    }

    /// Extra-usage credits are real money against a monthly cap, so they get the
    /// same treatment as a quota window.
    private func checkSpend(_ snapshot: UsageSnapshot) {
        guard let spend = snapshot.spend, let percent = spend.chargePercent else { return }
        let key = "\(snapshot.id).extra-usage"
        // Re-arm monthly: the cap resets with the billing month and the API
        // reports no reset timestamp for it, so there's no date to compare.
        let month = Self.monthMarker()
        if monthMarkers[key] != month {
            fired[key] = []
            monthMarkers[key] = month
        }
        for threshold in Self.spendThresholds where percent >= Double(threshold) {
            guard fired[key, default: []].contains(threshold) == false else { continue }
            fired[key, default: []].insert(threshold)
            deliverSpend(snapshot: snapshot, spend: spend, percent: percent, threshold: threshold)
        }
    }

    private static func monthMarker() -> String {
        let parts = Calendar.current.dateComponents([.year, .month], from: Date())
        return "\(parts.year ?? 0)-\(parts.month ?? 0)"
    }

    private func deliverSpend(snapshot: UsageSnapshot, spend: SpendSummary,
                              percent: Double, threshold: Int) {
        let content = UNMutableNotificationContent()
        content.title = "\(snapshot.displayName): \(threshold)% of extra-usage credits used"
        var body = Format.usd(spend.chargedUSD ?? 0, cents: true)
        if let limit = spend.chargeLimitUSD {
            body += " of \(Format.usd(limit, cents: true))"
        }
        body += " charged this month · \(Format.percent(percent))"
        content.body = body
        content.sound = .default
        let id = "\(snapshot.id).extra-usage.\(Self.monthMarker()).\(threshold)"
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: id, content: content, trigger: nil))
    }

    private func deliver(snapshot: UsageSnapshot, window: UsageWindow, threshold: Int) {
        let content = UNMutableNotificationContent()
        content.title = "\(snapshot.displayName): \(threshold)% of \(window.label) quota used"
        var body = "Currently at \(Format.percent(window.usedPercent))"
        if let countdown = Format.countdown(to: window.resetDate) { body += " · \(countdown)" }
        content.body = body
        content.sound = .default
        let id = "\(snapshot.id).\(window.label).\(threshold)"
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: nil))
    }

    /// Show banners even while the app is frontmost.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
