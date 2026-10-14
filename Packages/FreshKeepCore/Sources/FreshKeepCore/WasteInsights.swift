import Foundation

/// Minimal, storage independent view of an item used for statistics.
public struct ItemRecord: Hashable, Sendable {
    public let name: String
    public let category: FoodCategory
    public let status: ItemStatus
    public let price: Double
    public let addedAt: Date
    public let expiresAt: Date
    public let resolvedAt: Date?

    public init(name: String, category: FoodCategory, status: ItemStatus, price: Double,
                addedAt: Date, expiresAt: Date, resolvedAt: Date?) {
        self.name = name
        self.category = category
        self.status = status
        self.price = price
        self.addedAt = addedAt
        self.expiresAt = expiresAt
        self.resolvedAt = resolvedAt
    }
}

/// One bar in the weekly chart.
public struct WeeklyBucket: Identifiable, Hashable, Sendable {
    public var id: Date { weekStart }
    public let weekStart: Date
    public let eaten: Int
    public let wasted: Int
}

/// Aggregated numbers for the Insights screen.
public struct WasteSummary: Equatable, Sendable {
    public let eatenCount: Int
    public let wastedCount: Int
    public let moneySaved: Double
    public let moneyWasted: Double
    /// Share of resolved items that were eaten, 0...1. Nil before anything is resolved.
    public let rescueRate: Double?
    public let wastedByCategory: [FoodCategory: Int]
    /// CO2e avoided, using ~2.5 kg CO2e per kg of food and ~0.25 kg per item.
    public var co2SavedKg: Double { Double(eatenCount) * 0.25 * 2.5 }
}

public struct WasteInsights: Sendable {
    public var calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    public func summary(for records: [ItemRecord]) -> WasteSummary {
        let eaten = records.filter { $0.status == .eaten }
        let wasted = records.filter { $0.status == .wasted }
        let resolved = eaten.count + wasted.count
        var byCategory: [FoodCategory: Int] = [:]
        for item in wasted { byCategory[item.category, default: 0] += 1 }
        return WasteSummary(
            eatenCount: eaten.count,
            wastedCount: wasted.count,
            moneySaved: eaten.reduce(0) { $0 + $1.price },
            moneyWasted: wasted.reduce(0) { $0 + $1.price },
            rescueRate: resolved == 0 ? nil : Double(eaten.count) / Double(resolved),
            wastedByCategory: byCategory
        )
    }

    /// Eaten / wasted counts for each of the last `weeks` weeks, oldest first.
    public func weekly(for records: [ItemRecord], weeks: Int = 6, now: Date = Date()) -> [WeeklyBucket] {
        guard let thisWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return [] }
        return (0..<weeks).reversed().compactMap { offset in
            guard let start = calendar.date(byAdding: .weekOfYear, value: -offset, to: thisWeek),
                  let end = calendar.date(byAdding: .weekOfYear, value: 1, to: start) else { return nil }
            let inWeek = records.filter { record in
                guard let resolved = record.resolvedAt else { return false }
                return resolved >= start && resolved < end
            }
            return WeeklyBucket(weekStart: start,
                                eaten: inWeek.filter { $0.status == .eaten }.count,
                                wasted: inWeek.filter { $0.status == .wasted }.count)
        }
    }

    /// Consecutive days, ending today, on which nothing was thrown away
    /// (counted from the first day the user started tracking).
    public func zeroWasteStreak(for records: [ItemRecord], now: Date = Date()) -> Int {
        guard let firstDay = records.map(\.addedAt).min() else { return 0 }
        let wasteDays = Set(records.compactMap { record -> Date? in
            guard record.status == .wasted, let resolved = record.resolvedAt else { return nil }
            return calendar.startOfDay(for: resolved)
        })
        var streak = 0
        var day = calendar.startOfDay(for: now)
        let start = calendar.startOfDay(for: firstDay)
        while day >= start, !wasteDays.contains(day) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }
}
