import Foundation
import SwiftData
import FreshKeepCore

/// A food item the user is tracking. Persisted with SwiftData (Core Data under the hood).
///
/// Enum-backed properties are stored as raw strings so the store schema stays simple and
/// `#Predicate` queries (which cannot see computed properties) can filter on them.
@Model
final class PantryItem {
    @Attribute(.unique) var id: UUID
    var name: String
    /// Id of the matching `FoodProfile` in the shelf-life catalog, if any.
    var catalogID: String?
    var categoryRaw: String
    var storageRaw: String
    var quantity: Int
    var addedAt: Date
    var expiresAt: Date
    var price: Double
    var notes: String
    /// Photos are stored outside the SQLite file so list queries stay fast.
    @Attribute(.externalStorage) var photoData: Data?
    var statusRaw: String
    var resolvedAt: Date?
    /// How the expiry date was decided: estimated from the catalog, read from a label, or typed in.
    var expirySourceRaw: String

    init(id: UUID = UUID(), name: String, catalogID: String? = nil, category: FoodCategory,
         storage: StorageLocation, quantity: Int = 1, addedAt: Date = .now, expiresAt: Date,
         price: Double = 0, notes: String = "", photoData: Data? = nil,
         status: ItemStatus = .active, resolvedAt: Date? = nil, expirySource: ExpirySource = .estimated) {
        self.id = id
        self.name = name
        self.catalogID = catalogID
        self.categoryRaw = category.rawValue
        self.storageRaw = storage.rawValue
        self.quantity = quantity
        self.addedAt = addedAt
        self.expiresAt = expiresAt
        self.price = price
        self.notes = notes
        self.photoData = photoData
        self.statusRaw = status.rawValue
        self.resolvedAt = resolvedAt
        self.expirySourceRaw = expirySource.rawValue
    }
}

enum ExpirySource: String, Codable {
    case estimated, label, manual

    var label: String {
        switch self {
        case .estimated: "Estimated by FreshKeep"
        case .label: "Read from label"
        case .manual: "Entered manually"
        }
    }
}

extension PantryItem {
    static let activeStatus = ItemStatus.active.rawValue

    var category: FoodCategory {
        get { FoodCategory(rawValue: categoryRaw) ?? .pantry }
        set { categoryRaw = newValue.rawValue }
    }

    var storage: StorageLocation {
        get { StorageLocation(rawValue: storageRaw) ?? .fridge }
        set { storageRaw = newValue.rawValue }
    }

    var status: ItemStatus {
        get { ItemStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }

    var expirySource: ExpirySource {
        get { ExpirySource(rawValue: expirySourceRaw) ?? .manual }
        set { expirySourceRaw = newValue.rawValue }
    }

    var profile: FoodProfile? {
        catalogID.flatMap { id in ShelfLifeCatalog.shared.profiles.first { $0.id == id } }
            ?? ShelfLifeCatalog.shared.profile(named: name)
    }

    var emoji: String { profile?.emoji ?? "🍽️" }

    func freshness(now: Date = .now) -> Freshness {
        FreshnessCalculator(useSoonThreshold: AppSettings.useSoonThreshold)
            .freshness(added: addedAt, expires: expiresAt, now: now)
    }

    /// Value snapshot used by the statistics engine in FreshKeepCore.
    var record: ItemRecord {
        ItemRecord(name: name, category: category, status: status, price: price * Double(quantity),
                   addedAt: addedAt, expiresAt: expiresAt, resolvedAt: resolvedAt)
    }

    /// Marks the item as eaten or wasted and timestamps it for the insights charts.
    func resolve(as status: ItemStatus, at date: Date = .now) {
        self.status = status
        resolvedAt = status == .active ? nil : date
    }

    /// Moves an item into the freezer and extends its expiry using the catalog.
    /// Returns false when freezing does not make sense (already frozen or no gain).
    @discardableResult
    func freeze(now: Date = .now) -> Bool {
        guard storage != .freezer else { return false }
        let days = profile?.shelfLife[.freezer] ?? FoodCategory.frozen.fallbackShelfLifeDays
        let calendar = Calendar.current
        guard let newExpiry = calendar.date(byAdding: .day, value: days, to: calendar.startOfDay(for: now)),
              newExpiry > expiresAt else { return false }
        storage = .freezer
        expiresAt = newExpiry
        expirySource = .estimated
        return true
    }
}

/// Settings shared through UserDefaults (also bound with @AppStorage in the UI).
enum AppSettings {
    static let hasOnboardedKey = "hasOnboarded"
    static let remindersEnabledKey = "remindersEnabled"
    static let reminderLeadDaysKey = "reminderLeadDays"
    static let reminderHourKey = "reminderHour"
    static let appearanceKey = "appearance"
    static let useSoonThresholdKey = "useSoonThreshold"

    static var useSoonThreshold: Int {
        let value = UserDefaults.standard.integer(forKey: useSoonThresholdKey)
        return value == 0 ? 2 : value
    }

    static var reminderLeadDays: Int {
        let value = UserDefaults.standard.integer(forKey: reminderLeadDaysKey)
        return value == 0 ? 2 : value
    }

    static var reminderHour: Int {
        let value = UserDefaults.standard.integer(forKey: reminderHourKey)
        return value == 0 ? 9 : value
    }

    static var remindersEnabled: Bool {
        UserDefaults.standard.object(forKey: remindersEnabledKey) as? Bool ?? true
    }
}
