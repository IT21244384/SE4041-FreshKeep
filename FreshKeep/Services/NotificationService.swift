import Foundation
import UserNotifications
import FreshKeepCore

/// Schedules local "use it soon" reminders for pantry items.
protocol NotificationScheduling {
    func requestAuthorization() async -> Bool
    func schedule(itemID: UUID, name: String, expiresAt: Date)
    func cancel(itemID: UUID)
    func cancelAll()
}

struct NotificationService: NotificationScheduling {
    private var center: UNUserNotificationCenter { .current() }

    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func schedule(itemID: UUID, name: String, expiresAt: Date) {
        cancel(itemID: itemID)
        guard AppSettings.remindersEnabled else { return }
        let planner = ReminderPlanner(calendar: .current, hour: AppSettings.reminderHour)
        let plans = planner.plans(itemName: name, expiresAt: expiresAt, leadDays: AppSettings.reminderLeadDays)
        for (index, plan) in plans.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = plan.title
            content.body = plan.body
            content.sound = .default
            content.userInfo = ["itemID": itemID.uuidString]
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: plan.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            center.add(UNNotificationRequest(identifier: identifier(itemID, index), content: content, trigger: trigger))
        }
    }

    func cancel(itemID: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: (0..<2).map { identifier(itemID, $0) })
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }

    private func identifier(_ id: UUID, _ index: Int) -> String { "\(id.uuidString)-\(index)" }
}
