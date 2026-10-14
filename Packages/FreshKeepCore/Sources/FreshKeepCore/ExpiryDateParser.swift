import Foundation

/// Extracts a "best before" / "use by" date from text recognised on a food label.
///
/// Packaging in Sri Lanka and the UK prints day-first dates, so ambiguous numeric
/// dates such as 05/11/26 are read as 5 November 2026. Formats handled:
///  - 12/11/2026, 12-11-26, 12.11.2026     (day first)
///  - 2026-11-12, 2026/11/12               (ISO, year first)
///  - 12 NOV 2026, 12 Nov 26, NOV 12 2026  (month names)
///  - 11/2026, NOV 2026                    (month + year -> last day of month)
/// When several dates appear (e.g. MFD and EXP) the one after an expiry keyword
/// wins, otherwise the latest date is used because manufacture dates come first.
public struct ExpiryDateParser: Sendable {
    public var calendar: Calendar
    public var dayFirst: Bool

    public init(calendar: Calendar = Calendar(identifier: .gregorian), dayFirst: Bool = true) {
        self.calendar = calendar
        self.dayFirst = dayFirst
    }

    static let expiryKeywords = ["best before", "best by", "use by", "use before", "bb", "bbe", "exp", "expiry",
                                 "expires", "expiration", "exp date", "consume before", "sell by"]
    static let manufactureKeywords = ["mfd", "mfg", "manufactured", "packed on", "pkd", "prod", "production date"]

    static let months: [String: Int] = [
        "jan": 1, "january": 1, "feb": 2, "february": 2, "mar": 3, "march": 3, "apr": 4, "april": 4,
        "may": 5, "jun": 6, "june": 6, "jul": 7, "july": 7, "aug": 8, "august": 8, "sep": 9, "sept": 9,
        "september": 9, "oct": 10, "october": 10, "nov": 11, "november": 11, "dec": 12, "december": 12
    ]

    /// A date found in the text, with its position so we can relate it to keywords.
    struct Candidate {
        let date: Date
        let position: Int
    }

    /// Returns the most likely expiry date, or nil when no date is present.
    public func parse(_ text: String) -> Date? {
        let lowered = text.lowercased()
        let candidates = findDates(in: lowered)
        guard !candidates.isEmpty else { return nil }

        // Prefer the first date that follows an expiry keyword and is not right after a manufacture keyword.
        let expiryPositions = keywordPositions(Self.expiryKeywords, in: lowered)
        let manufacturePositions = keywordPositions(Self.manufactureKeywords, in: lowered)
        for candidate in candidates {
            let nearestExpiry = expiryPositions.filter { $0 <= candidate.position }.max() ?? -1
            let nearestManufacture = manufacturePositions.filter { $0 <= candidate.position }.max() ?? -1
            if nearestExpiry >= 0 && nearestExpiry > nearestManufacture {
                return candidate.date
            }
        }
        return candidates.map(\.date).max()
    }

    // MARK: - Matching

    private func findDates(in text: String) -> [Candidate] {
        var results: [Candidate] = []
        let ns = text as NSString
        let fullRange = NSRange(location: 0, length: ns.length)
        var consumed = IndexSet()

        func add(_ pattern: String, _ build: ([String]) -> Date?) {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
            for match in regex.matches(in: text, range: fullRange) {
                let range = match.range
                // Skip text already claimed by a more specific pattern.
                if consumed.contains(integersIn: range.location..<(range.location + range.length)) { continue }
                var groups: [String] = []
                for i in 1..<match.numberOfRanges {
                    let r = match.range(at: i)
                    groups.append(r.location == NSNotFound ? "" : ns.substring(with: r))
                }
                if let date = build(groups) {
                    results.append(Candidate(date: date, position: range.location))
                }
                // Claim the text even when the date is invalid (31/02/2026), so a looser
                // pattern cannot re-read part of it as "02/2026".
                consumed.insert(integersIn: range.location..<(range.location + range.length))
            }
        }

        let monthNames = "(jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|june?|july?|aug(?:ust)?|sep(?:t(?:ember)?)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)"

        // ISO: 2026-11-12
        add(#"\b(20\d{2})[-/.](\d{1,2})[-/.](\d{1,2})\b"#) { g in
            makeDate(day: Int(g[2]), month: Int(g[1]), year: Int(g[0]))
        }
        // 12 nov 2026 / 12-nov-26
        add(#"\b(\d{1,2})[\s\-./]*"# + monthNames + #"[\s\-./,]*(\d{2,4})\b"#) { g in
            makeDate(day: Int(g[0]), month: Self.months[g[1]], year: Int(g[2]))
        }
        // nov 12 2026 / nov 12, 26
        add(monthNames + #"[\s\-./]*(\d{1,2})[\s,\-./]+(\d{4}|\d{2})\b"#) { g in
            makeDate(day: Int(g[1]), month: Self.months[g[0]], year: Int(g[2]))
        }
        // 12/11/2026, 12.11.26 (day first by default)
        add(#"\b(\d{1,2})[/.\-](\d{1,2})[/.\-](\d{4}|\d{2})\b"#) { g in
            guard let a = Int(g[0]), let b = Int(g[1]) else { return nil }
            // If the first number cannot be a month, it must be the day (and vice versa).
            var (day, month) = dayFirst ? (a, b) : (b, a)
            if month > 12 && day <= 12 { swap(&day, &month) }
            return makeDate(day: day, month: month, year: Int(g[2]))
        }
        // nov 2026 -> end of month
        add(monthNames + #"[\s\-./]*(20\d{2}|\d{2})\b"#) { g in
            endOfMonth(month: Self.months[g[0]], year: Int(g[1]))
        }
        // 11/2026 -> end of month
        add(#"\b(\d{1,2})[/.\-](20\d{2})\b"#) { g in
            endOfMonth(month: Int(g[0]), year: Int(g[1]))
        }
        return results.sorted { $0.position < $1.position }
    }

    private func keywordPositions(_ keywords: [String], in text: String) -> [Int] {
        var positions: [Int] = []
        let ns = text as NSString
        for keyword in keywords {
            let escaped = NSRegularExpression.escapedPattern(for: keyword)
            guard let regex = try? NSRegularExpression(pattern: "\\b" + escaped + "\\b") else { continue }
            for match in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
                positions.append(match.range.location)
            }
        }
        return positions
    }

    private func normalizeYear(_ year: Int) -> Int {
        year < 100 ? 2000 + year : year
    }

    private func makeDate(day: Int?, month: Int?, year: Int?) -> Date? {
        guard let day, let month, let year, (1...12).contains(month), (1...31).contains(day) else { return nil }
        var components = DateComponents()
        components.year = normalizeYear(year)
        components.month = month
        components.day = day
        guard let date = calendar.date(from: components),
              calendar.component(.day, from: date) == day else { return nil } // rejects 31/02
        return date
    }

    private func endOfMonth(month: Int?, year: Int?) -> Date? {
        guard let month, let year, (1...12).contains(month) else { return nil }
        var components = DateComponents()
        components.year = normalizeYear(year)
        components.month = month
        components.day = 1
        guard let first = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: first) else { return nil }
        components.day = range.count
        return calendar.date(from: components)
    }
}
