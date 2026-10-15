import SwiftUI
import FreshKeepCore

/// Simple recipe card with a cook-along checklist.
struct RecipeDetailView: View {
    let suggestion: RecipeSuggestion
    @State private var doneSteps: Set<Int> = []

    private let catalog = ShelfLifeCatalog.shared

    var body: some View {
        List {
            Section {
                HStack(spacing: Spacing.l) {
                    Text(suggestion.recipe.emoji).font(.system(size: 64))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(suggestion.recipe.title).font(.rounded(.title2, weight: .bold))
                        Label("\(suggestion.recipe.minutes) minutes", systemImage: "clock")
                            .font(.rounded(.subheadline)).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, Spacing.s)
            }
            Section("You have") {
                ForEach(suggestion.usesUp, id: \.self) { id in
                    Label(name(id), systemImage: "checkmark.circle.fill").foregroundStyle(Color.brand)
                }
            }
            if !suggestion.missing.isEmpty {
                Section("You'll also need") {
                    ForEach(suggestion.missing, id: \.self) { id in
                        Label(name(id), systemImage: "cart").foregroundStyle(.secondary)
                    }
                }
            }
            Section("Steps") {
                ForEach(Array(suggestion.recipe.steps.enumerated()), id: \.offset) { index, step in
                    Button {
                        withAnimation(.snappySpring) {
                            if doneSteps.contains(index) { doneSteps.remove(index) } else { doneSteps.insert(index) }
                        }
                    } label: {
                        HStack(alignment: .top, spacing: Spacing.m) {
                            Image(systemName: doneSteps.contains(index) ? "checkmark.circle.fill" : "\(index + 1).circle")
                                .font(.title3)
                                .foregroundStyle(doneSteps.contains(index) ? Color.brand : Color.secondary)
                                .contentTransition(.symbolEffect(.replace))
                            Text(step)
                                .strikethrough(doneSteps.contains(index))
                                .foregroundStyle(doneSteps.contains(index) ? .secondary : .primary)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityValue(doneSteps.contains(index) ? "Done" : "Not done")
                }
            }
        }
        .navigationTitle("Recipe")
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.selection, trigger: doneSteps)
    }

    private func name(_ id: String) -> String {
        guard let profile = catalog.profiles.first(where: { $0.id == id }) else { return id }
        return "\(profile.emoji) \(profile.name)"
    }
}
