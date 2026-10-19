import Foundation

/// How urgent an item is, derived from its expiry date.
public enum FreshnessLevel: Int, Comparable, CaseIterable, Sendable {
    case expired = 0, expiresToday, useSoon, fresh

    public static func < (lhs: FreshnessLevel, rhs: FreshnessLevel) -> Bool { lhs.rawValue < rhs.rawValue }

    public var title: String {
        switch self {
        case .expired: "Expired"
        case .expiresToday: "Use today"
        case .useSoon: "Use soon"
        case .fresh: "Fresh"
        }
    }

    /// Name of the colour in the app's asset catalog.
    public var colorName: String {
        switch self {
        case .expired: "FreshExpired"
        case .expiresToday: "FreshToday"
        case .useSoon: "FreshSoon"
        case .fresh: "FreshGood"
        }
    }
}

/// Snapshot of an item's freshness at a given moment.
public struct Freshness: Equatable, Sendable {
    public let level: FreshnessLevel
    /// Whole calendar days until expiry (negative once expired).
    public let daysLeft: Int
    /// 1.0 when just added, 0.0 at expiry. Drives the freshness ring.
    public let remainingFraction: Double

    public init(level: FreshnessLevel, daysLeft: Int, remainingFraction: Double) {
        self.level = level
        self.daysLeft = daysLeft
        self.remainingFraction = remainingFraction
    }

    /// Human friendly summary such as "3 days left" or "Expired 2 days ago".
    public var summary: String {
        switch daysLeft {
        case ..<(-1): "Expired \(-daysLeft) days ago"
        case -1: "Expired yesterday"
        case 0: "Expires today"
        case 1: "1 day left"
        default: "\(daysLeft) days left"
        }
    }
}

/// Pure functions for computing freshness. Kept separate from the data model
/// so it is easy to unit test with fixed dates.
public struct FreshnessCalculator: Sendable {
    public var calendar: Calendar
    /// Items with this many days or fewer left are flagged "use soon".
    public var useSoonThreshold: Int

    public init(calendar: Calendar = .current, useSoonThreshold: Int = 2) {
        self.calendar = calendar
        self.useSoonThreshold = useSoonThreshold
    }

    public func daysLeft(until expiry: Date, now: Date = Date()) -> Int {
        let start = calendar.startOfDay(for: now)
        let end = calendar.startOfDay(for: expiry)
        return calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }

    public func freshness(added: Date, expires: Date, now: Date = Date()) -> Freshness {
        let days = daysLeft(until: expires, now: now)
        let level: FreshnessLevel
        switch days {
        case ..<0: level = .expired
        case 0: level = .expiresToday
        case 1...useSoonThreshold: level = .useSoon
        default: level = .fresh
        }
        let total = max(expires.timeIntervalSince(added), 1)
        let remaining = expires.timeIntervalSince(now)
        let fraction = min(max(remaining / total, 0), 1)
        return Freshness(level: level, daysLeft: days, remainingFraction: days < 0 ? 0 : fraction)
    }
}
