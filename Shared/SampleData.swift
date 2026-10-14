import Foundation
import SwiftData
import FreshKeepCore

/// Demo pantry used by previews, UI tests, the visionOS prototype and the
/// "Load sample pantry" button in Settings.
enum SampleData {
    /// (catalog id, storage, days from now until expiry, quantity)
    private static let activeItems: [(String, StorageLocation, Int, Int)] = [
        ("banana", .counter, 0, 4),
        ("milk", .fridge, 1, 1),
        ("spinach", .fridge, 2, 1),
        ("strawberry", .fridge, -1, 1),
        ("chicken", .fridge, 1, 1),
        ("tomato", .counter, 3, 5),
        ("carrot", .fridge, 12, 6),
        ("egg", .fridge, 18, 10),
        ("cheese", .fridge, 20, 1),
        ("bread", .counter, 2, 1),
        ("mango", .counter, 4, 2),
        ("rice", .fridge, 1, 1)
    ]

    /// Past items so the Insights charts have six weeks of history.
    private static let history: [(String, ItemStatus, Int)] = [
        ("apple", .eaten, 2), ("yogurt", .eaten, 3), ("lettuce", .wasted, 4), ("banana", .eaten, 6),
        ("bread", .eaten, 8), ("milk", .wasted, 10), ("orange", .eaten, 12), ("chicken", .eaten, 13),
        ("cucumber", .eaten, 16), ("mushroom", .wasted, 18), ("grapes", .eaten, 20), ("fish", .eaten, 22),
        ("tomato", .eaten, 25), ("spinach", .wasted, 27), ("egg", .eaten, 29), ("cheese", .eaten, 31),
        ("papaya", .wasted, 33), ("carrot", .eaten, 35), ("curry", .eaten, 37), ("beans", .eaten, 39)
    ]

    @MainActor
    static func insert(into context: ModelContext, now: Date = .now) {
        let catalog = ShelfLifeCatalog.shared
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)

        for (id, storage, daysLeft, quantity) in activeItems {
            guard let profile = catalog.profiles.first(where: { $0.id == id }) else { continue }
            let expires = calendar.date(byAdding: .day, value: daysLeft, to: today)!
            let shelfLife = profile.shelfLifeDays(in: storage)
            let added = calendar.date(byAdding: .day, value: -max(shelfLife - daysLeft, 1), to: today)!
            context.insert(PantryItem(name: profile.name, catalogID: profile.id, category: profile.category,
                                      storage: storage, quantity: quantity, addedAt: added, expiresAt: expires,
                                      price: profile.typicalPrice))
        }

        for (id, status, daysAgo) in history {
            guard let profile = catalog.profiles.first(where: { $0.id == id }) else { continue }
            let resolved = calendar.date(byAdding: .day, value: -daysAgo, to: now)!
            let added = calendar.date(byAdding: .day, value: -profile.shelfLifeDays(in: profile.recommendedStorage), to: resolved)!
            let expires = calendar.date(byAdding: .day, value: profile.shelfLifeDays(in: profile.recommendedStorage), to: added)!
            context.insert(PantryItem(name: profile.name, catalogID: profile.id, category: profile.category,
                                      storage: profile.recommendedStorage, addedAt: added, expiresAt: expires,
                                      price: profile.typicalPrice, status: status, resolvedAt: resolved))
        }
        try? context.save()
    }

    /// In-memory container pre-filled with sample data, for SwiftUI previews.
    @MainActor
    static let previewContainer: ModelContainer = {
        let container = try! ModelContainer(for: PantryItem.self,
                                            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        insert(into: container.mainContext)
        return container
    }()
}
