import Foundation
import FreshKeepCore

/// Editable, unsaved copy of an item. The add/edit form works on a draft so
/// cancelling never touches the SwiftData store.
struct ItemDraft: Equatable {
    var name = ""
    var catalogID: String?
    var category: FoodCategory = .fruit
    var storage: StorageLocation = .fridge
    var quantity = 1
    var addedAt = Date.now
    var expiresAt = Calendar.current.date(byAdding: .day, value: 5, to: Calendar.current.startOfDay(for: .now)) ?? .now
    var price: Double = 0
    var notes = ""
    var photoData: Data?
    var expirySource: ExpirySource = .estimated

    private var catalog: ShelfLifeCatalog { .shared }

    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    var isValid: Bool { !trimmedName.isEmpty && quantity > 0 }

    var profile: FoodProfile? {
        catalogID.flatMap { id in catalog.profiles.first { $0.id == id } } ?? catalog.profile(named: trimmedName)
    }

    /// Fills the draft from a catalog food (used by scan results and name suggestions).
    init(profile: FoodProfile, storage: StorageLocation? = nil, photoData: Data? = nil) {
        self.name = profile.name
        self.catalogID = profile.id
        self.category = profile.category
        self.storage = storage ?? profile.recommendedStorage
        self.price = profile.typicalPrice
        self.photoData = photoData
        self.expiresAt = ShelfLifeCatalog.shared.suggestedExpiry(for: profile, storage: self.storage)
        self.expirySource = .estimated
    }

    /// Draft for a recognised category without a specific food (e.g. "fruit").
    init(category: FoodCategory, photoData: Data? = nil) {
        self.category = category
        self.photoData = photoData
        self.expiresAt = ShelfLifeCatalog.shared.suggestedExpiry(for: category)
    }

    init() {}

    init(item: PantryItem) {
        name = item.name
        catalogID = item.catalogID
        category = item.category
        storage = item.storage
        quantity = item.quantity
        addedAt = item.addedAt
        expiresAt = item.expiresAt
        price = item.price
        notes = item.notes
        photoData = item.photoData
        expirySource = item.expirySource
    }

    /// Applies a catalog food chosen from the suggestions list.
    mutating func apply(_ profile: FoodProfile) {
        name = profile.name
        catalogID = profile.id
        category = profile.category
        storage = profile.recommendedStorage
        if price == 0 { price = profile.typicalPrice }
        reestimateExpiry()
    }

    /// Recomputes the estimated expiry, unless the user entered or scanned a real date.
    mutating func reestimateExpiry() {
        guard expirySource == .estimated else { return }
        if let profile {
            expiresAt = catalog.suggestedExpiry(for: profile, storage: storage, from: addedAt)
        } else {
            expiresAt = catalog.suggestedExpiry(for: category, from: addedAt)
        }
    }

    var estimatedShelfLifeDays: Int {
        profile?.shelfLifeDays(in: storage) ?? category.fallbackShelfLifeDays
    }

    func makeItem() -> PantryItem {
        PantryItem(name: trimmedName, catalogID: catalogID ?? profile?.id, category: category, storage: storage,
                   quantity: quantity, addedAt: addedAt, expiresAt: expiresAt, price: price, notes: notes,
                   photoData: photoData, expirySource: expirySource)
    }

    func apply(to item: PantryItem) {
        item.name = trimmedName
        item.catalogID = catalogID ?? profile?.id
        item.category = category
        item.storage = storage
        item.quantity = quantity
        item.expiresAt = expiresAt
        item.price = price
        item.notes = notes
        if item.photoData != photoData { ImagePipeline.clearCache() }
        item.photoData = photoData
        item.expirySource = expirySource
    }
}
