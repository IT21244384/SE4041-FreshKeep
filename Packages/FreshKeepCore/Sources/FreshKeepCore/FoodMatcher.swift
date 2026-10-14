import Foundation

/// A raw label coming out of an image classifier (Vision / Core ML).
public struct ClassifierObservation: Hashable, Sendable {
    public let identifier: String
    public let confidence: Double

    public init(identifier: String, confidence: Double) {
        self.identifier = identifier
        self.confidence = confidence
    }
}

/// A food suggestion shown to the user after a scan.
public struct FoodMatch: Identifiable, Hashable, Sendable {
    public var id: String { profile?.id ?? "category-\(category.rawValue)" }
    /// Specific food, or nil when only a category could be recognised ("fruit").
    public let profile: FoodProfile?
    public let category: FoodCategory
    public let confidence: Double
    public let sourceLabel: String

    public var displayName: String { profile?.name ?? category.displayName }
    public var emoji: String { profile?.emoji ?? "🍽️" }
}

/// Turns classifier observations into ranked food matches.
///
/// The on-device classifier knows ~1,300 generic labels; only a subset are foods.
/// The matcher filters out non-food labels, merges duplicates (e.g. "granny_smith"
/// and "apple" both mean Apple) and keeps the highest confidence per food.
public struct FoodMatcher: Sendable {
    public let catalog: ShelfLifeCatalog
    /// Observations below this confidence are ignored as noise.
    public let minimumConfidence: Double

    /// Generic labels that tell us the category but not the exact food.
    static let categoryLabels: [String: FoodCategory] = [
        "fruit": .fruit, "citrus fruit": .fruit, "berry": .fruit, "produce": .vegetable,
        "vegetable": .vegetable, "leafy green": .vegetable, "root vegetable": .vegetable,
        "dairy": .dairy, "meat": .meat, "poultry": .meat, "seafood": .seafood,
        "baked goods": .bakery, "bakery": .bakery, "dessert": .bakery,
        "beverage": .beverage, "drink": .beverage, "frozen food": .frozen
    ]

    public init(catalog: ShelfLifeCatalog = .shared, minimumConfidence: Double = 0.08) {
        self.catalog = catalog
        self.minimumConfidence = minimumConfidence
    }

    public func matches(from observations: [ClassifierObservation], limit: Int = 5) -> [FoodMatch] {
        var specific: [String: FoodMatch] = [:]
        var generic: [FoodCategory: FoodMatch] = [:]

        for observation in observations where observation.confidence >= minimumConfidence {
            let label = ShelfLifeCatalog.normalize(observation.identifier)
            if let profile = catalog.profile(named: label) {
                if (specific[profile.id]?.confidence ?? -1) < observation.confidence {
                    specific[profile.id] = FoodMatch(profile: profile, category: profile.category,
                                                     confidence: observation.confidence, sourceLabel: label)
                }
            } else if let category = Self.categoryLabels[label] {
                if (generic[category]?.confidence ?? -1) < observation.confidence {
                    generic[category] = FoodMatch(profile: nil, category: category,
                                                  confidence: observation.confidence, sourceLabel: label)
                }
            }
        }

        // A specific food always beats a bare category for the same group.
        let foodCategories = Set(specific.values.map(\.category))
        let categoryOnly = generic.values.filter { !foodCategories.contains($0.category) }

        let ranked = specific.values.sorted { $0.confidence > $1.confidence }
            + categoryOnly.sorted { $0.confidence > $1.confidence }
        return Array(ranked.prefix(limit))
    }
}
