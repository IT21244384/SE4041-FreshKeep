import Foundation

/// Decides when expiry reminders should fire. The app turns these plans into
/// UNNotificationRequests; keeping the timing logic here makes it testable.
public struct ReminderPlan: Equatable, Sendable {
    public let fireDate: Date
    public let title: String
    public let body: String
}

public struct ReminderPlanner: Sendable {
    public var calendar: Calendar
    /// Hour of day (24h) at which reminders are delivered.
    public var hour: Int

    public init(calendar: Calendar = .current, hour: Int = 9) {
        self.calendar = calendar
        self.hour = hour
    }

    /// - Parameters:
    ///   - leadDays: how many days before expiry the "use soon" reminder fires.
    /// - Returns: reminders that are still in the future, earliest first.
    public func plans(itemName: String, expiresAt: Date, leadDays: Int, now: Date = Date()) -> [ReminderPlan] {
        var plans: [ReminderPlan] = []
        let expiryDay = calendar.startOfDay(for: expiresAt)

        if leadDays > 0,
           let early = calendar.date(byAdding: .day, value: -leadDays, to: expiryDay),
           let fire = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: early) {
            let dayWord = leadDays == 1 ? "tomorrow" : "in \(leadDays) days"
            plans.append(ReminderPlan(fireDate: fire, title: "Use your \(itemName) soon",
                                      body: "\(itemName) expires \(dayWord). Tap for recipe ideas."))
        }
        if let fire = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: expiryDay) {
            plans.append(ReminderPlan(fireDate: fire, title: "\(itemName) expires today",
                                      body: "Eat it, freeze it or share it before it goes to waste."))
        }
        return plans.filter { $0.fireDate > now }.sorted { $0.fireDate < $1.fireDate }
    }
}
