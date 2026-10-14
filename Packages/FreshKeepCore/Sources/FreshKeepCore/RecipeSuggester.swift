import Foundation

/// A simple, offline recipe idea that uses up ingredients.
public struct Recipe: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let emoji: String
    public let minutes: Int
    /// Catalog ids of the key ingredients.
    public let ingredientIDs: [String]
    public let steps: [String]

    public init(id: String, title: String, emoji: String, minutes: Int, ingredientIDs: [String], steps: [String]) {
        self.id = id
        self.title = title
        self.emoji = emoji
        self.minutes = minutes
        self.ingredientIDs = ingredientIDs
        self.steps = steps
    }
}

/// A recipe ranked against what is in the pantry.
public struct RecipeSuggestion: Identifiable, Hashable, Sendable {
    public var id: String { recipe.id }
    public let recipe: Recipe
    /// Ingredients the user has, most urgent first.
    public let usesUp: [String]
    public let missing: [String]
    /// Higher is better: rewards using items that are about to expire.
    public let score: Double
}

/// Ranks recipes so that the ones which rescue soon-to-expire food come first.
public struct RecipeSuggester: Sendable {
    public let recipes: [Recipe]

    public init(recipes: [Recipe] = RecipeSuggester.defaultRecipes) {
        self.recipes = recipes
    }

    /// - Parameter available: catalog id -> days left for each active pantry item.
    public func suggestions(available: [String: Int], limit: Int = 5) -> [RecipeSuggestion] {
        recipes.compactMap { recipe -> RecipeSuggestion? in
            let have = recipe.ingredientIDs.filter { available[$0] != nil }
            guard !have.isEmpty else { return nil }
            // Urgent items (few days left) are worth more; expired items are not suggested.
            let urgency = have.reduce(0.0) { total, id in
                let days = available[id] ?? 99
                return days < 0 ? total : total + 1.0 / Double(max(days, 0) + 1)
            }
            let coverage = Double(have.count) / Double(recipe.ingredientIDs.count)
            let ordered = have.sorted { (available[$0] ?? 99) < (available[$1] ?? 99) }
            return RecipeSuggestion(recipe: recipe, usesUp: ordered,
                                    missing: recipe.ingredientIDs.filter { available[$0] == nil },
                                    score: urgency * 2 + coverage)
        }
        .filter { $0.score > 0 }
        .sorted { $0.score == $1.score ? $0.recipe.title < $1.recipe.title : $0.score > $1.score }
        .prefix(limit)
        .map { $0 }
    }
}

public extension RecipeSuggester {
    static let defaultRecipes: [Recipe] = [
        Recipe(id: "banana-smoothie", title: "Banana Smoothie", emoji: "🥤", minutes: 5,
               ingredientIDs: ["banana", "milk", "yogurt"],
               steps: ["Peel and slice the bananas.", "Blend with milk and yogurt until smooth.", "Serve cold or freeze as popsicles."]),
        Recipe(id: "banana-bread", title: "Banana Bread", emoji: "🍞", minutes: 60,
               ingredientIDs: ["banana", "egg", "butter"],
               steps: ["Mash 3 ripe bananas.", "Mix with 2 eggs, melted butter, 1 cup sugar and 2 cups flour.", "Bake at 175°C for 50 minutes."]),
        Recipe(id: "veg-fried-rice", title: "Vegetable Fried Rice", emoji: "🍳", minutes: 15,
               ingredientIDs: ["rice", "carrot", "egg", "beans", "onion"],
               steps: ["Fry onion, diced carrot and beans.", "Push aside, scramble the eggs.", "Add day-old rice, soy sauce and toss on high heat."]),
        Recipe(id: "tomato-curry", title: "Tomato & Egg Curry", emoji: "🍛", minutes: 25,
               ingredientIDs: ["tomato", "egg", "onion", "coconut", "chili"],
               steps: ["Sauté onion and chilli.", "Add chopped tomatoes and curry powder; cook down.", "Add coconut milk and boiled eggs, simmer 5 minutes."]),
        Recipe(id: "stir-fry", title: "Quick Veggie Stir-fry", emoji: "🥢", minutes: 15,
               ingredientIDs: ["broccoli", "bell-pepper", "carrot", "mushroom", "garlic"],
               steps: ["Slice everything thinly.", "Stir-fry garlic, then the harder veg first.", "Finish with soy sauce and a splash of water."]),
        Recipe(id: "omelette", title: "Fridge-clearing Omelette", emoji: "🍳", minutes: 10,
               ingredientIDs: ["egg", "spinach", "tomato", "cheese", "mushroom"],
               steps: ["Whisk 3 eggs with salt and pepper.", "Wilt the greens and veg in a pan.", "Pour over eggs, top with cheese, fold."]),
        Recipe(id: "fruit-salad", title: "Tropical Fruit Salad", emoji: "🥗", minutes: 10,
               ingredientIDs: ["mango", "pineapple", "papaya", "banana", "orange"],
               steps: ["Cube all the fruit.", "Squeeze over orange or lime juice.", "Chill for 10 minutes."]),
        Recipe(id: "chicken-curry", title: "Chicken Curry", emoji: "🍲", minutes: 45,
               ingredientIDs: ["chicken", "onion", "tomato", "garlic", "ginger", "coconut"],
               steps: ["Marinate chicken in curry powder.", "Fry onion, garlic and ginger; add tomato.", "Add chicken and coconut milk; simmer 30 minutes."]),
        Recipe(id: "fish-ambul", title: "Fish Ambul Thiyal", emoji: "🐟", minutes: 35,
               ingredientIDs: ["fish", "garlic", "ginger", "chili"],
               steps: ["Cube the fish.", "Coat with goraka paste, pepper, garlic and ginger.", "Cook covered on low heat until dry."]),
        Recipe(id: "veg-soup", title: "Leftover Veg Soup", emoji: "🥣", minutes: 30,
               ingredientIDs: ["carrot", "potato", "onion", "cabbage", "pumpkin", "beans"],
               steps: ["Chop whatever veg you have.", "Simmer in stock for 20 minutes.", "Blend half for a creamy texture."]),
        Recipe(id: "salad-bowl", title: "Crunchy Salad Bowl", emoji: "🥗", minutes: 10,
               ingredientIDs: ["lettuce", "cucumber", "tomato", "carrot", "avocado"],
               steps: ["Wash and chop the vegetables.", "Slice avocado on top.", "Dress with lemon, oil and salt."]),
        Recipe(id: "french-toast", title: "French Toast", emoji: "🍞", minutes: 15,
               ingredientIDs: ["bread", "egg", "milk", "butter"],
               steps: ["Whisk eggs and milk.", "Soak slightly stale bread.", "Fry in butter until golden."]),
        Recipe(id: "pasta-bake", title: "Leftover Pasta Bake", emoji: "🍝", minutes: 30,
               ingredientIDs: ["pasta", "cheese", "tomato", "sausage"],
               steps: ["Mix pasta with chopped tomato and sausage.", "Top with cheese.", "Bake at 200°C for 20 minutes."]),
        Recipe(id: "prawn-devilled", title: "Devilled Prawns", emoji: "🦐", minutes: 20,
               ingredientIDs: ["prawns", "onion", "bell-pepper", "tomato", "chili"],
               steps: ["Fry prawns until pink; set aside.", "Stir-fry onion, peppers and chilli.", "Add tomato sauce and prawns; toss."])
    ]
}
