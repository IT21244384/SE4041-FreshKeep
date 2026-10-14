import Foundation

/// Broad grouping used for filtering, icons and default shelf life.
public enum FoodCategory: String, CaseIterable, Codable, Identifiable, Sendable {
    case fruit, vegetable, dairy, meat, seafood, bakery, eggs, pantry, frozen, leftovers, beverage

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .fruit: "Fruit"
        case .vegetable: "Vegetables"
        case .dairy: "Dairy"
        case .meat: "Meat"
        case .seafood: "Seafood"
        case .bakery: "Bakery"
        case .eggs: "Eggs"
        case .pantry: "Pantry"
        case .frozen: "Frozen"
        case .leftovers: "Leftovers"
        case .beverage: "Drinks"
        }
    }

    /// SF Symbol name shown next to items of this category.
    public var symbolName: String {
        switch self {
        case .fruit: "apple.logo"
        case .vegetable: "carrot.fill"
        case .dairy: "drop.fill"
        case .meat: "fork.knife"
        case .seafood: "fish.fill"
        case .bakery: "birthday.cake.fill"
        case .eggs: "oval.portrait.fill"
        case .pantry: "takeoutbag.and.cup.and.straw.fill"
        case .frozen: "snowflake"
        case .leftovers: "takeoutbag.and.cup.and.straw"
        case .beverage: "cup.and.saucer.fill"
        }
    }

    /// Shelf life used when a food is not in the catalog.
    public var fallbackShelfLifeDays: Int {
        switch self {
        case .fruit: 5
        case .vegetable: 6
        case .dairy: 7
        case .meat: 2
        case .seafood: 2
        case .bakery: 4
        case .eggs: 21
        case .pantry: 180
        case .frozen: 90
        case .leftovers: 3
        case .beverage: 10
        }
    }
}

/// Where the item is kept. Storage changes shelf life a lot.
public enum StorageLocation: String, CaseIterable, Codable, Identifiable, Sendable {
    case fridge, freezer, pantry, counter

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .fridge: "Fridge"
        case .freezer: "Freezer"
        case .pantry: "Pantry"
        case .counter: "Counter"
        }
    }

    public var symbolName: String {
        switch self {
        case .fridge: "refrigerator.fill"
        case .freezer: "snowflake"
        case .pantry: "cabinet.fill"
        case .counter: "sun.max.fill"
        }
    }
}

/// Lifecycle of a pantry item. Eaten/wasted items feed the insights screen.
public enum ItemStatus: String, Codable, CaseIterable, Sendable {
    case active, eaten, wasted
}
