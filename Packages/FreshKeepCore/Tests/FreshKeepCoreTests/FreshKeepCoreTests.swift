import XCTest
@testable import FreshKeepCore

/// Shared fixed calendar so tests don't depend on the machine's locale or time zone.
private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    calendar.firstWeekday = 2 // Monday
    return calendar
}()

private func day(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0) -> Date {
    utc.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
}

final class ExpiryDateParserTests: XCTestCase {
    let parser = ExpiryDateParser(calendar: utc)

    func testDayFirstSlashDate() {
        XCTAssertEqual(parser.parse("BEST BEFORE 05/11/2026"), day(2026, 11, 5))
    }

    func testTwoDigitYearWithDots() {
        XCTAssertEqual(parser.parse("BB 12.11.26"), day(2026, 11, 12))
    }

    func testISODate() {
        XCTAssertEqual(parser.parse("EXP 2026-12-01"), day(2026, 12, 1))
    }

    func testMonthNameDayFirst() {
        XCTAssertEqual(parser.parse("Use by 12 NOV 2026"), day(2026, 11, 12))
    }

    func testMonthNameMonthFirst() {
        XCTAssertEqual(parser.parse("Best by Nov 3, 2026"), day(2026, 11, 3))
    }

    func testMonthAndYearOnlyMeansEndOfMonth() {
        XCTAssertEqual(parser.parse("EXP 02/2028"), day(2028, 2, 29))
        XCTAssertEqual(parser.parse("BEST BEFORE DEC 2026"), day(2026, 12, 31))
    }

    func testSwapsWhenDayCannotBeMonth() {
        // 11/25/2026 is only valid as month-first.
        XCTAssertEqual(parser.parse("EXP 11/25/2026"), day(2026, 11, 25))
    }

    func testPrefersExpiryOverManufactureDate() {
        let label = "MFD 01/10/2026  EXP 01/04/2027  BATCH 42"
        XCTAssertEqual(parser.parse(label), day(2027, 4, 1))
    }

    func testManufactureAfterExpiryKeywordOrder() {
        let label = "EXP: 15/01/2027\nMFD: 15/07/2026"
        XCTAssertEqual(parser.parse(label), day(2027, 1, 15))
    }

    func testFallsBackToLatestDateWithoutKeywords() {
        XCTAssertEqual(parser.parse("10/10/2026 20/10/2026"), day(2026, 10, 20))
    }

    func testRejectsImpossibleDates() {
        XCTAssertNil(parser.parse("EXP 31/02/2026"))
        XCTAssertNil(parser.parse("Net weight 500g"))
    }

    func testMultilineOCRNoise() {
        let ocr = "KOTMALE\nFRESH MILK\n1L\nUSE BY:\n18 OCT 26\nKeep refrigerated"
        XCTAssertEqual(parser.parse(ocr), day(2026, 10, 18))
    }
}

final class ShelfLifeCatalogTests: XCTestCase {
    let catalog = ShelfLifeCatalog()

    func testLookupByNameAliasAndPlural() {
        XCTAssertEqual(catalog.profile(named: "Banana")?.id, "banana")
        XCTAssertEqual(catalog.profile(named: "granny_smith")?.id, "apple")
        XCTAssertEqual(catalog.profile(named: "carrots")?.id, "carrot")
        XCTAssertEqual(catalog.profile(named: "tomatoes")?.id, "tomato")
        XCTAssertEqual(catalog.profile(named: "head_cabbage")?.id, "cabbage")
        XCTAssertNil(catalog.profile(named: "laptop"))
    }

    func testShelfLifeDependsOnStorage() throws {
        let banana = try XCTUnwrap(catalog.profile(named: "banana"))
        XCTAssertEqual(banana.shelfLifeDays(in: .counter), 5)
        XCTAssertEqual(banana.shelfLifeDays(in: .freezer), 90)
        // Unsupported storage falls back to the recommended location.
        XCTAssertEqual(banana.shelfLifeDays(in: .pantry), 5)
    }

    func testSuggestedExpiryStartsFromStartOfDay() throws {
        let milk = try XCTUnwrap(catalog.profile(named: "milk"))
        let expiry = catalog.suggestedExpiry(for: milk, storage: .fridge, from: day(2026, 10, 14, 18), calendar: utc)
        XCTAssertEqual(expiry, day(2026, 10, 21))
    }

    func testSearchRanksPrefixMatchesFirst() {
        let results = catalog.search("ca")
        XCTAssertEqual(results.first?.name, "Carrot")
        XCTAssertTrue(results.contains { $0.id == "cabbage" })
    }

    func testAliasesAreUniqueAcrossProfiles() {
        var seen: [String: String] = [:]
        for profile in catalog.profiles {
            for alias in [profile.id, profile.name] + profile.aliases {
                let key = ShelfLifeCatalog.normalize(alias)
                if let owner = seen[key], owner != profile.id {
                    XCTFail("\(key) is used by both \(owner) and \(profile.id)")
                }
                seen[key] = profile.id
            }
        }
    }

    func testCatalogPerformance() {
        measure {
            for _ in 0..<2_000 { _ = catalog.profile(named: "granny_smith") }
        }
    }
}

final class FoodMatcherTests: XCTestCase {
    let matcher = FoodMatcher()

    func testMergesAliasesAndKeepsHighestConfidence() {
        let matches = matcher.matches(from: [
            .init(identifier: "granny_smith", confidence: 0.62),
            .init(identifier: "apple", confidence: 0.30),
            .init(identifier: "fruit", confidence: 0.90),
            .init(identifier: "lemon", confidence: 0.12)
        ])
        XCTAssertEqual(matches.map(\.id), ["apple", "lemon"])
        XCTAssertEqual(matches.first?.confidence, 0.62)
    }

    func testFallsBackToCategoryWhenNoSpecificFood() {
        let matches = matcher.matches(from: [
            .init(identifier: "vegetable", confidence: 0.7),
            .init(identifier: "structure", confidence: 0.9)
        ])
        XCTAssertEqual(matches.count, 1)
        XCTAssertNil(matches.first?.profile)
        XCTAssertEqual(matches.first?.category, .vegetable)
    }

    func testIgnoresLowConfidenceAndNonFood() {
        let matches = matcher.matches(from: [
            .init(identifier: "banana", confidence: 0.02),
            .init(identifier: "table", confidence: 0.95)
        ])
        XCTAssertTrue(matches.isEmpty)
    }
}

final class FreshnessCalculatorTests: XCTestCase {
    let calculator = FreshnessCalculator(calendar: utc, useSoonThreshold: 2)

    func testLevels() {
        let added = day(2026, 10, 1)
        XCTAssertEqual(calculator.freshness(added: added, expires: day(2026, 10, 20), now: day(2026, 10, 14, 10)).level, .fresh)
        XCTAssertEqual(calculator.freshness(added: added, expires: day(2026, 10, 16), now: day(2026, 10, 14, 10)).level, .useSoon)
        XCTAssertEqual(calculator.freshness(added: added, expires: day(2026, 10, 14, 23), now: day(2026, 10, 14, 10)).level, .expiresToday)
        XCTAssertEqual(calculator.freshness(added: added, expires: day(2026, 10, 12), now: day(2026, 10, 14, 10)).level, .expired)
    }

    func testRemainingFractionIsClamped() {
        let f = calculator.freshness(added: day(2026, 10, 10), expires: day(2026, 10, 20), now: day(2026, 10, 15))
        XCTAssertEqual(f.remainingFraction, 0.5, accuracy: 0.001)
        XCTAssertEqual(calculator.freshness(added: day(2026, 10, 10), expires: day(2026, 10, 12), now: day(2026, 10, 15)).remainingFraction, 0)
    }

    func testSummaryText() {
        let added = day(2026, 10, 1)
        let now = day(2026, 10, 14)
        XCTAssertEqual(calculator.freshness(added: added, expires: day(2026, 10, 17), now: now).summary, "3 days left")
        XCTAssertEqual(calculator.freshness(added: added, expires: day(2026, 10, 15), now: now).summary, "1 day left")
        XCTAssertEqual(calculator.freshness(added: added, expires: day(2026, 10, 13), now: now).summary, "Expired yesterday")
        XCTAssertEqual(calculator.freshness(added: added, expires: day(2026, 10, 10), now: now).summary, "Expired 4 days ago")
    }
}

final class WasteInsightsTests: XCTestCase {
    let insights = WasteInsights(calendar: utc)

    private func record(_ status: ItemStatus, price: Double = 100, category: FoodCategory = .fruit,
                        added: Date = day(2026, 10, 1), resolved: Date?) -> ItemRecord {
        ItemRecord(name: "x", category: category, status: status, price: price,
                   addedAt: added, expiresAt: day(2026, 10, 20), resolvedAt: resolved)
    }

    func testSummaryTotals() {
        let summary = insights.summary(for: [
            record(.eaten, price: 200, resolved: day(2026, 10, 5)),
            record(.eaten, price: 50, resolved: day(2026, 10, 6)),
            record(.wasted, price: 120, category: .dairy, resolved: day(2026, 10, 7)),
            record(.active, resolved: nil)
        ])
        XCTAssertEqual(summary.eatenCount, 2)
        XCTAssertEqual(summary.wastedCount, 1)
        XCTAssertEqual(summary.moneySaved, 250)
        XCTAssertEqual(summary.moneyWasted, 120)
        XCTAssertEqual(summary.rescueRate ?? 0, 2.0 / 3.0, accuracy: 0.0001)
        XCTAssertEqual(summary.wastedByCategory[.dairy], 1)
    }

    func testRescueRateNilWhenNothingResolved() {
        XCTAssertNil(insights.summary(for: [record(.active, resolved: nil)]).rescueRate)
    }

    func testWeeklyBuckets() {
        let now = day(2026, 10, 14) // Wednesday
        let buckets = insights.weekly(for: [
            record(.eaten, resolved: day(2026, 10, 13)),
            record(.wasted, resolved: day(2026, 10, 14)),
            record(.eaten, resolved: day(2026, 10, 6))
        ], weeks: 3, now: now)
        XCTAssertEqual(buckets.count, 3)
        XCTAssertEqual(buckets.last?.weekStart, day(2026, 10, 12))
        XCTAssertEqual(buckets.last?.eaten, 1)
        XCTAssertEqual(buckets.last?.wasted, 1)
        XCTAssertEqual(buckets[1].eaten, 1)
        XCTAssertEqual(buckets[0].eaten, 0)
    }

    func testZeroWasteStreak() {
        let now = day(2026, 10, 14, 12)
        let records = [
            record(.eaten, added: day(2026, 10, 1), resolved: day(2026, 10, 12)),
            record(.wasted, added: day(2026, 10, 1), resolved: day(2026, 10, 10, 15))
        ]
        // Oct 11, 12, 13, 14 are clean.
        XCTAssertEqual(insights.zeroWasteStreak(for: records, now: now), 4)
        XCTAssertEqual(insights.zeroWasteStreak(for: [], now: now), 0)
    }
}

final class RecipeSuggesterTests: XCTestCase {
    let suggester = RecipeSuggester()

    func testPrefersRecipesUsingUrgentItems() {
        let suggestions = suggester.suggestions(available: ["banana": 0, "milk": 5, "carrot": 10])
        XCTAssertEqual(suggestions.first?.recipe.id, "banana-smoothie")
        XCTAssertEqual(suggestions.first?.usesUp, ["banana", "milk"])
        XCTAssertEqual(suggestions.first?.missing, ["yogurt"])
    }

    func testNoSuggestionsForEmptyPantry() {
        XCTAssertTrue(suggester.suggestions(available: [:]).isEmpty)
    }

    func testRecipeIngredientsExistInCatalog() {
        let catalog = ShelfLifeCatalog()
        for recipe in suggester.recipes {
            for id in recipe.ingredientIDs {
                XCTAssertNotNil(catalog.profiles.first { $0.id == id }, "\(recipe.id) uses unknown ingredient \(id)")
            }
        }
    }
}

final class ReminderPlannerTests: XCTestCase {
    let planner = ReminderPlanner(calendar: utc, hour: 9)

    func testPlansEarlyAndSameDayReminders() {
        let plans = planner.plans(itemName: "Milk", expiresAt: day(2026, 10, 20, 18), leadDays: 2, now: day(2026, 10, 14))
        XCTAssertEqual(plans.map(\.fireDate), [day(2026, 10, 18, 9), day(2026, 10, 20, 9)])
        XCTAssertEqual(plans.first?.title, "Use your Milk soon")
        XCTAssertTrue(plans.first?.body.contains("in 2 days") ?? false)
    }

    func testDropsRemindersInThePast() {
        let plans = planner.plans(itemName: "Bread", expiresAt: day(2026, 10, 15), leadDays: 3, now: day(2026, 10, 14, 12))
        XCTAssertEqual(plans.map(\.fireDate), [day(2026, 10, 15, 9)])
    }
}
