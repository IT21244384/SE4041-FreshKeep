import Foundation

/// One food the app knows about: how long it keeps and how to store it.
public struct FoodProfile: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let emoji: String
    public let category: FoodCategory
    /// Labels (lower-case, space separated) that the on-device classifier may return for this food.
    public let aliases: [String]
    /// Typical shelf life in days for each storage location the food suits.
    public let shelfLife: [StorageLocation: Int]
    public let recommendedStorage: StorageLocation
    public let storageTip: String
    /// Rough unit price in LKR, used to estimate money saved / wasted.
    public let typicalPrice: Double

    public init(id: String, name: String, emoji: String, category: FoodCategory, aliases: [String] = [],
                shelfLife: [StorageLocation: Int], recommendedStorage: StorageLocation,
                storageTip: String, typicalPrice: Double) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.category = category
        self.aliases = aliases
        self.shelfLife = shelfLife
        self.recommendedStorage = recommendedStorage
        self.storageTip = storageTip
        self.typicalPrice = typicalPrice
    }

    /// Shelf life for a storage location, falling back to the recommended one.
    public func shelfLifeDays(in storage: StorageLocation) -> Int {
        shelfLife[storage] ?? shelfLife[recommendedStorage] ?? category.fallbackShelfLifeDays
    }
}

/// Built-in knowledge base of common foods (values based on USDA FoodKeeper guidance,
/// rounded for a home kitchen in a warm climate).
public struct ShelfLifeCatalog: Sendable {
    public let profiles: [FoodProfile]
    private let index: [String: FoodProfile]

    public init(profiles: [FoodProfile] = ShelfLifeCatalog.defaultProfiles) {
        self.profiles = profiles
        var index: [String: FoodProfile] = [:]
        for profile in profiles {
            for key in [profile.id, profile.name] + profile.aliases {
                let normalized = Self.normalize(key)
                // First registration wins so a specific food is never shadowed by a later alias.
                if index[normalized] == nil { index[normalized] = profile }
            }
        }
        self.index = index
    }

    public static let shared = ShelfLifeCatalog()

    /// Lower-cases and turns classifier style identifiers ("bell_pepper") into words.
    public static func normalize(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Exact lookup by id, name or alias. Also tries the singular form ("apples" -> "apple").
    public func profile(named name: String) -> FoodProfile? {
        let key = Self.normalize(name)
        if let match = index[key] { return match }
        if key.hasSuffix("es"), let match = index[String(key.dropLast(2))] { return match }
        if key.hasSuffix("s"), let match = index[String(key.dropLast())] { return match }
        return nil
    }

    /// Case-insensitive prefix/substring search used by the manual add form.
    public func search(_ query: String, limit: Int = 8) -> [FoodProfile] {
        let q = Self.normalize(query)
        guard !q.isEmpty else { return Array(profiles.prefix(limit)) }
        let prefix = profiles.filter { Self.normalize($0.name).hasPrefix(q) }
        let contains = profiles.filter { p in
            !prefix.contains(p) && (Self.normalize(p.name).contains(q) || p.aliases.contains { $0.contains(q) })
        }
        return Array((prefix + contains).prefix(limit))
    }

    /// Suggested expiry date for a food stored in a location.
    public func suggestedExpiry(for profile: FoodProfile, storage: StorageLocation,
                                from date: Date = Date(), calendar: Calendar = .current) -> Date {
        let days = profile.shelfLifeDays(in: storage)
        let start = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: days, to: start) ?? date
    }

    /// Suggested expiry for an unknown food, based only on its category.
    public func suggestedExpiry(for category: FoodCategory, from date: Date = Date(),
                                calendar: Calendar = .current) -> Date {
        let start = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: category.fallbackShelfLifeDays, to: start) ?? date
    }
}

public extension ShelfLifeCatalog {
    static let defaultProfiles: [FoodProfile] = [
        // Fruit
        FoodProfile(id: "apple", name: "Apple", emoji: "🍎", category: .fruit,
                    aliases: ["granny smith", "red apple", "green apple"],
                    shelfLife: [.counter: 7, .fridge: 30], recommendedStorage: .fridge,
                    storageTip: "Keep apples in the crisper drawer away from other produce; they release ethylene.", typicalPrice: 120),
        FoodProfile(id: "banana", name: "Banana", emoji: "🍌", category: .fruit, aliases: ["bananas", "plantain"],
                    shelfLife: [.counter: 5, .fridge: 7, .freezer: 90], recommendedStorage: .counter,
                    storageTip: "Store on the counter and wrap the stems. Freeze peeled ripe bananas for smoothies.", typicalPrice: 30),
        FoodProfile(id: "orange", name: "Orange", emoji: "🍊", category: .fruit, aliases: ["mandarin", "tangerine", "clementine"],
                    shelfLife: [.counter: 7, .fridge: 21], recommendedStorage: .fridge,
                    storageTip: "Citrus lasts three times longer in the fridge in a mesh bag.", typicalPrice: 90),
        FoodProfile(id: "lemon", name: "Lemon", emoji: "🍋", category: .fruit, aliases: ["lime"],
                    shelfLife: [.counter: 7, .fridge: 28], recommendedStorage: .fridge,
                    storageTip: "Seal lemons in a zip bag in the fridge to keep them juicy.", typicalPrice: 40),
        FoodProfile(id: "strawberry", name: "Strawberries", emoji: "🍓", category: .fruit, aliases: ["strawberry"],
                    shelfLife: [.fridge: 4, .freezer: 180], recommendedStorage: .fridge,
                    storageTip: "Don't wash until you eat them. Line the box with a paper towel.", typicalPrice: 650),
        FoodProfile(id: "grapes", name: "Grapes", emoji: "🍇", category: .fruit, aliases: ["grape"],
                    shelfLife: [.fridge: 10, .freezer: 180], recommendedStorage: .fridge,
                    storageTip: "Keep grapes on the stem, unwashed, in a vented bag.", typicalPrice: 900),
        FoodProfile(id: "mango", name: "Mango", emoji: "🥭", category: .fruit,
                    shelfLife: [.counter: 4, .fridge: 7, .freezer: 180], recommendedStorage: .counter,
                    storageTip: "Ripen on the counter, then move to the fridge to slow it down.", typicalPrice: 250),
        FoodProfile(id: "pineapple", name: "Pineapple", emoji: "🍍", category: .fruit,
                    shelfLife: [.counter: 3, .fridge: 5], recommendedStorage: .counter,
                    storageTip: "Store upside down for a day so the sweetness spreads; cut pieces go in the fridge.", typicalPrice: 350),
        FoodProfile(id: "watermelon", name: "Watermelon", emoji: "🍉", category: .fruit,
                    shelfLife: [.counter: 7, .fridge: 4], recommendedStorage: .counter,
                    storageTip: "Whole melons keep on the counter; cover cut melon and refrigerate.", typicalPrice: 400),
        FoodProfile(id: "avocado", name: "Avocado", emoji: "🥑", category: .fruit,
                    shelfLife: [.counter: 4, .fridge: 7], recommendedStorage: .counter,
                    storageTip: "Ripen on the counter; once ripe, refrigerate to gain a few extra days.", typicalPrice: 200),
        FoodProfile(id: "pear", name: "Pear", emoji: "🍐", category: .fruit,
                    shelfLife: [.counter: 4, .fridge: 12], recommendedStorage: .fridge,
                    storageTip: "Ripen at room temperature, then chill.", typicalPrice: 180),
        FoodProfile(id: "papaya", name: "Papaya", emoji: "🧡", category: .fruit,
                    shelfLife: [.counter: 3, .fridge: 6], recommendedStorage: .counter,
                    storageTip: "Wrap cut papaya tightly; it absorbs fridge smells.", typicalPrice: 300),
        // Vegetables
        FoodProfile(id: "tomato", name: "Tomato", emoji: "🍅", category: .vegetable, aliases: ["tomatoes", "cherry tomato"],
                    shelfLife: [.counter: 5, .fridge: 10], recommendedStorage: .counter,
                    storageTip: "Store stem-side down at room temperature for best flavour.", typicalPrice: 60),
        FoodProfile(id: "carrot", name: "Carrot", emoji: "🥕", category: .vegetable, aliases: ["carrots"],
                    shelfLife: [.fridge: 21, .counter: 4], recommendedStorage: .fridge,
                    storageTip: "Cut off the green tops and keep carrots in a damp cloth in the fridge.", typicalPrice: 50),
        FoodProfile(id: "broccoli", name: "Broccoli", emoji: "🥦", category: .vegetable,
                    shelfLife: [.fridge: 5, .freezer: 300], recommendedStorage: .fridge,
                    storageTip: "Wrap loosely in a damp paper towel; blanch before freezing.", typicalPrice: 450),
        FoodProfile(id: "cauliflower", name: "Cauliflower", emoji: "🥬", category: .vegetable,
                    shelfLife: [.fridge: 7], recommendedStorage: .fridge,
                    storageTip: "Store head-side down so moisture doesn't pool on the florets.", typicalPrice: 300),
        FoodProfile(id: "cabbage", name: "Cabbage", emoji: "🥬", category: .vegetable, aliases: ["head cabbage"],
                    shelfLife: [.fridge: 30], recommendedStorage: .fridge,
                    storageTip: "Keep whole and remove outer leaves only when using.", typicalPrice: 120),
        FoodProfile(id: "lettuce", name: "Lettuce", emoji: "🥬", category: .vegetable, aliases: ["leaf lettuce", "salad", "iceberg"],
                    shelfLife: [.fridge: 5], recommendedStorage: .fridge,
                    storageTip: "Wash, dry completely and store in a box lined with paper towel.", typicalPrice: 200),
        FoodProfile(id: "spinach", name: "Spinach", emoji: "🌿", category: .vegetable, aliases: ["greens", "leafy greens"],
                    shelfLife: [.fridge: 4, .freezer: 240], recommendedStorage: .fridge,
                    storageTip: "Use within a few days; wilting leaves are perfect for curries.", typicalPrice: 100),
        FoodProfile(id: "cucumber", name: "Cucumber", emoji: "🥒", category: .vegetable, aliases: ["zucchini", "courgette"],
                    shelfLife: [.fridge: 7, .counter: 3], recommendedStorage: .fridge,
                    storageTip: "Wrap in a towel and keep in the warmest part of the fridge (the door).", typicalPrice: 80),
        FoodProfile(id: "bell-pepper", name: "Bell Pepper", emoji: "🫑", category: .vegetable,
                    aliases: ["bell pepper", "pepper", "capsicum", "pepper veggie", "green pepper", "red pepper"],
                    shelfLife: [.fridge: 10], recommendedStorage: .fridge,
                    storageTip: "Keep dry and whole in the crisper drawer.", typicalPrice: 150),
        FoodProfile(id: "chili", name: "Green Chilli", emoji: "🌶️", category: .vegetable, aliases: ["chili pepper", "chilli", "hot pepper", "jalapeno"],
                    shelfLife: [.fridge: 14, .freezer: 180], recommendedStorage: .fridge,
                    storageTip: "Remove stems before refrigerating; they last much longer.", typicalPrice: 40),
        FoodProfile(id: "onion", name: "Onion", emoji: "🧅", category: .vegetable, aliases: ["onions", "red onion", "shallot"],
                    shelfLife: [.pantry: 30, .fridge: 60], recommendedStorage: .pantry,
                    storageTip: "Cool, dark and ventilated — never next to potatoes.", typicalPrice: 40),
        FoodProfile(id: "garlic", name: "Garlic", emoji: "🧄", category: .vegetable,
                    shelfLife: [.pantry: 90], recommendedStorage: .pantry,
                    storageTip: "Whole bulbs keep for months in a dry, airy spot.", typicalPrice: 60),
        FoodProfile(id: "potato", name: "Potato", emoji: "🥔", category: .vegetable, aliases: ["potatoes", "sweet potato"],
                    shelfLife: [.pantry: 30], recommendedStorage: .pantry,
                    storageTip: "Store in a dark, cool place; light turns them green.", typicalPrice: 45),
        FoodProfile(id: "mushroom", name: "Mushrooms", emoji: "🍄", category: .vegetable, aliases: ["mushroom", "button mushroom"],
                    shelfLife: [.fridge: 5], recommendedStorage: .fridge,
                    storageTip: "Keep in a paper bag, never sealed plastic.", typicalPrice: 400),
        FoodProfile(id: "corn", name: "Corn", emoji: "🌽", category: .vegetable, aliases: ["ear", "corn cob", "maize"],
                    shelfLife: [.fridge: 3, .freezer: 240], recommendedStorage: .fridge,
                    storageTip: "Leave the husk on until cooking.", typicalPrice: 100),
        FoodProfile(id: "eggplant", name: "Brinjal", emoji: "🍆", category: .vegetable, aliases: ["eggplant", "aubergine"],
                    shelfLife: [.fridge: 5, .counter: 2], recommendedStorage: .fridge,
                    storageTip: "Eggplants bruise easily; keep them unwrapped on top of the crisper.", typicalPrice: 80),
        FoodProfile(id: "pumpkin", name: "Pumpkin", emoji: "🎃", category: .vegetable, aliases: ["squash", "butternut squash"],
                    shelfLife: [.pantry: 60, .fridge: 5], recommendedStorage: .pantry,
                    storageTip: "Whole pumpkins last months; wrap cut pieces and refrigerate.", typicalPrice: 150),
        FoodProfile(id: "beans", name: "Green Beans", emoji: "🫛", category: .vegetable, aliases: ["green beans", "string beans", "peas"],
                    shelfLife: [.fridge: 6, .freezer: 240], recommendedStorage: .fridge,
                    storageTip: "Store unwashed in a perforated bag.", typicalPrice: 120),
        FoodProfile(id: "ginger", name: "Ginger", emoji: "🫚", category: .vegetable,
                    shelfLife: [.fridge: 21, .freezer: 180], recommendedStorage: .fridge,
                    storageTip: "Freeze ginger and grate it straight from frozen.", typicalPrice: 60),
        // Dairy & eggs
        FoodProfile(id: "milk", name: "Milk", emoji: "🥛", category: .dairy, aliases: ["milk can", "milk carton"],
                    shelfLife: [.fridge: 7], recommendedStorage: .fridge,
                    storageTip: "Keep milk at the back of the fridge, not the door.", typicalPrice: 420),
        FoodProfile(id: "yogurt", name: "Yogurt", emoji: "🥣", category: .dairy, aliases: ["yoghurt", "curd"],
                    shelfLife: [.fridge: 10], recommendedStorage: .fridge,
                    storageTip: "Always use a clean spoon to avoid mould.", typicalPrice: 90),
        FoodProfile(id: "cheese", name: "Cheese", emoji: "🧀", category: .dairy, aliases: ["cheddar", "mozzarella", "cheese slice"],
                    shelfLife: [.fridge: 21, .freezer: 180], recommendedStorage: .fridge,
                    storageTip: "Wrap in wax paper, then loosely in plastic.", typicalPrice: 900),
        FoodProfile(id: "butter", name: "Butter", emoji: "🧈", category: .dairy,
                    shelfLife: [.fridge: 60, .freezer: 270], recommendedStorage: .fridge,
                    storageTip: "Keep a small amount out; freeze the rest.", typicalPrice: 1100),
        FoodProfile(id: "egg", name: "Eggs", emoji: "🥚", category: .eggs, aliases: ["eggs", "egg carton", "boiled egg"],
                    shelfLife: [.fridge: 28, .counter: 10], recommendedStorage: .fridge,
                    storageTip: "Store in the original carton, pointed end down.", typicalPrice: 55),
        // Meat & seafood
        FoodProfile(id: "chicken", name: "Chicken", emoji: "🍗", category: .meat, aliases: ["poultry", "chicken breast", "drumstick"],
                    shelfLife: [.fridge: 2, .freezer: 270], recommendedStorage: .fridge,
                    storageTip: "Keep raw chicken on the bottom shelf; freeze if not cooking within 2 days.", typicalPrice: 1400),
        FoodProfile(id: "beef", name: "Beef", emoji: "🥩", category: .meat, aliases: ["steak", "red meat", "mince"],
                    shelfLife: [.fridge: 3, .freezer: 180], recommendedStorage: .fridge,
                    storageTip: "Mince spoils fastest — cook or freeze within a day.", typicalPrice: 2400),
        FoodProfile(id: "sausage", name: "Sausages", emoji: "🌭", category: .meat, aliases: ["sausage", "hot dog", "bacon"],
                    shelfLife: [.fridge: 7, .freezer: 60], recommendedStorage: .fridge,
                    storageTip: "Once opened, use within a week.", typicalPrice: 800),
        FoodProfile(id: "fish", name: "Fish", emoji: "🐟", category: .seafood, aliases: ["tuna", "salmon", "seer fish", "fish fillet"],
                    shelfLife: [.fridge: 2, .freezer: 180], recommendedStorage: .fridge,
                    storageTip: "Rest fish on ice in a container and cook within 2 days.", typicalPrice: 1800),
        FoodProfile(id: "prawns", name: "Prawns", emoji: "🦐", category: .seafood, aliases: ["shrimp", "prawn"],
                    shelfLife: [.fridge: 2, .freezer: 150], recommendedStorage: .fridge,
                    storageTip: "Freeze in water to prevent freezer burn.", typicalPrice: 2200),
        // Bakery & pantry
        FoodProfile(id: "bread", name: "Bread", emoji: "🍞", category: .bakery, aliases: ["loaf", "baguette", "bun", "toast", "sliced bread"],
                    shelfLife: [.counter: 4, .freezer: 90], recommendedStorage: .counter,
                    storageTip: "Freeze sliced bread and toast it straight from frozen.", typicalPrice: 180),
        FoodProfile(id: "cake", name: "Cake", emoji: "🍰", category: .bakery, aliases: ["pastry", "muffin", "cupcake", "croissant"],
                    shelfLife: [.counter: 2, .fridge: 5], recommendedStorage: .fridge,
                    storageTip: "Cream-filled bakes must stay in the fridge.", typicalPrice: 450),
        FoodProfile(id: "rice", name: "Cooked Rice", emoji: "🍚", category: .leftovers, aliases: ["rice", "fried rice"],
                    shelfLife: [.fridge: 3, .freezer: 30], recommendedStorage: .fridge,
                    storageTip: "Cool cooked rice within an hour and refrigerate.", typicalPrice: 150),
        FoodProfile(id: "curry", name: "Curry", emoji: "🍛", category: .leftovers, aliases: ["leftovers", "stew", "soup", "dhal"],
                    shelfLife: [.fridge: 3, .freezer: 90], recommendedStorage: .fridge,
                    storageTip: "Label leftovers with the date you cooked them.", typicalPrice: 300),
        FoodProfile(id: "pasta", name: "Pasta (cooked)", emoji: "🍝", category: .leftovers, aliases: ["pasta", "spaghetti", "noodles"],
                    shelfLife: [.fridge: 4], recommendedStorage: .fridge,
                    storageTip: "Toss with a little oil before refrigerating so it doesn't clump.", typicalPrice: 250),
        FoodProfile(id: "juice", name: "Juice", emoji: "🧃", category: .beverage, aliases: ["orange juice", "fruit juice", "smoothie"],
                    shelfLife: [.fridge: 7], recommendedStorage: .fridge,
                    storageTip: "Fresh juice loses vitamins quickly; drink within 2 days.", typicalPrice: 350),
        FoodProfile(id: "coconut", name: "Coconut", emoji: "🥥", category: .fruit, aliases: ["coconut milk", "scraped coconut"],
                    shelfLife: [.pantry: 14, .fridge: 4, .freezer: 90], recommendedStorage: .pantry,
                    storageTip: "Scraped coconut spoils in a day at room temperature — refrigerate it.", typicalPrice: 150)
    ]
}
