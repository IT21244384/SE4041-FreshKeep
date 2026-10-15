import SwiftUI
import SwiftData
import FreshKeepCore

/// Everything about one item: freshness ring, storage tip, recipe ideas and actions.
struct ItemDetailView: View {
    @Bindable var item: PantryItem

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppServices.self) private var services
    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var editing = false
    @State private var confirmDelete = false
    @State private var zoom: CGFloat = 1
    @State private var confettiTrigger = 0
    @State private var toast: String?
    @State private var heroAppeared = false

    private var freshness: Freshness { item.freshness() }

    private var recipes: [RecipeSuggestion] {
        guard let id = item.profile?.id else { return [] }
        return RecipeSuggester().suggestions(available: [id: freshness.daysLeft], limit: 3)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.l) {
                hero
                // Side by side on iPad / landscape, stacked on iPhone portrait.
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: Spacing.l) {
                        statusCard.frame(minWidth: 320)
                        infoCard.frame(minWidth: 320)
                    }
                    VStack(spacing: Spacing.l) {
                        statusCard
                        infoCard
                    }
                }
                if let tip = item.profile?.storageTip { tipCard(tip) }
                if !recipes.isEmpty { recipeCard }
                if item.status == .active { actions }
            }
            .padding()
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(Color.appBackground)
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button { editing = true } label: { Label("Edit", systemImage: "pencil") }
                    Button(role: .destructive) { confirmDelete = true } label: { Label("Delete", systemImage: "trash") }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $editing) {
            AddEditItemView(mode: .edit(item))
        }
        .confirmationDialog("Delete \(item.name)?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                services.notifications.cancel(itemID: item.id)
                context.delete(item)
                dismiss()
            }
        } message: {
            Text("This removes it without counting it as eaten or wasted.")
        }
        .overlay { ConfettiBurst(trigger: confettiTrigger) }
        .overlay(alignment: .bottom) { ToastView(message: $toast) }
        .sensoryFeedback(.success, trigger: confettiTrigger)
        .onAppear { withAnimation(.gentleSpring.delay(0.05)) { heroAppeared = true } }
    }

    // MARK: - Hero

    private var hero: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(LinearGradient(colors: [Color.freshness(freshness.level).opacity(0.35), Color.freshness(freshness.level).opacity(0.08)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            if let data = item.photoData, let image = ImagePipeline.downsample(data: data, maxPixelSize: 1200) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .scaleEffect(zoom)
                    // Pinch to zoom the photo; it springs back when released.
                    .gesture(
                        MagnifyGesture()
                            .onChanged { zoom = min(max($0.magnification, 1), 3) }
                            .onEnded { _ in withAnimation(.snappySpring) { zoom = 1 } }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .accessibilityLabel("Photo of \(item.name)")
            } else {
                Text(item.emoji)
                    .font(.system(size: 110))
                    .scaleEffect(heroAppeared ? 1 : 0.4)
                    .rotationEffect(.degrees(heroAppeared ? 0 : -25))
                    .accessibilityHidden(true)
            }
        }
        .frame(height: sizeClass == .regular ? 300 : 220)
    }

    // MARK: - Cards

    private var statusCard: some View {
        HStack(spacing: Spacing.l) {
            FreshnessRing(freshness: freshness, size: 96, lineWidth: 10)
            VStack(alignment: .leading, spacing: 6) {
                Text(item.status == .active ? freshness.level.title : item.status.rawValue.capitalized)
                    .font(.rounded(.title2, weight: .bold))
                    .foregroundStyle(Color.freshness(freshness.level))
                Text(freshness.summary)
                    .font(.rounded(.headline))
                Text("Best before \(item.expiresAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.rounded(.subheadline))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .freshCard()
        .accessibilityElement(children: .combine)
    }

    private var infoCard: some View {
        VStack(spacing: Spacing.m) {
            InfoRow(icon: item.category.symbolName, title: "Category", value: item.category.displayName)
            Divider()
            InfoRow(icon: item.storage.symbolName, title: "Stored in", value: item.storage.displayName)
            Divider()
            InfoRow(icon: "number", title: "Quantity", value: "\(item.quantity)")
            Divider()
            InfoRow(icon: "calendar.badge.plus", title: "Added", value: item.addedAt.formatted(date: .abbreviated, time: .omitted))
            Divider()
            InfoRow(icon: "sparkles", title: "Expiry", value: item.expirySource.label)
            if item.price > 0 {
                Divider()
                InfoRow(icon: "banknote", title: "Value", value: (item.price * Double(item.quantity)).formatted(.currency(code: "LKR").precision(.fractionLength(0))))
            }
            if !item.notes.isEmpty {
                Divider()
                Text(item.notes).frame(maxWidth: .infinity, alignment: .leading).foregroundStyle(.secondary)
            }
        }
        .freshCard()
    }

    private func tipCard(_ tip: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.m) {
            Image(systemName: "lightbulb.fill")
                .font(.title2)
                .foregroundStyle(Color.citrus)
            VStack(alignment: .leading, spacing: 4) {
                Text("Storage tip").font(.rounded(.headline))
                Text(tip).font(.rounded(.subheadline)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .freshCard()
    }

    private var recipeCard: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text("Use it up").font(.rounded(.headline))
            ForEach(recipes) { suggestion in
                NavigationLink {
                    RecipeDetailView(suggestion: suggestion)
                } label: {
                    HStack {
                        Text(suggestion.recipe.emoji).font(.title)
                        VStack(alignment: .leading) {
                            Text(suggestion.recipe.title).font(.rounded(.subheadline, weight: .semibold))
                            Text("\(suggestion.recipe.minutes) min").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .freshCard()
    }

    private var actions: some View {
        VStack(spacing: Spacing.m) {
            Button {
                withAnimation(.snappySpring) { item.resolve(as: .eaten) }
                services.notifications.cancel(itemID: item.id)
                confettiTrigger += 1
                withAnimation { toast = "Rescued! Nice work 🎉" }
            } label: {
                Label("I ate it", systemImage: "checkmark.circle.fill")
            }
            .buttonStyle(.primary)
            .accessibilityIdentifier("detail.eaten")

            HStack(spacing: Spacing.m) {
                if item.storage != .freezer {
                    Button {
                        let frozen = withAnimation(.snappySpring) { item.freeze() }
                        if frozen {
                            services.notifications.schedule(itemID: item.id, name: item.name, expiresAt: item.expiresAt)
                        }
                        withAnimation { toast = frozen ? "Moved to freezer ❄️ +\(freshness.daysLeft) days" : "Freezing won't help this one" }
                    } label: {
                        Label("Freeze", systemImage: "snowflake")
                    }
                    .buttonStyle(.soft(.blue))
                }
                Button {
                    withAnimation(.snappySpring) { item.resolve(as: .wasted) }
                    services.notifications.cancel(itemID: item.id)
                    withAnimation { toast = "Logged as wasted" }
                } label: {
                    Label("Wasted", systemImage: "xmark.bin.fill")
                }
                .buttonStyle(.soft(.orange))
            }
        }
    }
}

private struct InfoRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack {
            Label(title, systemImage: icon)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
        .font(.rounded(.subheadline))
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack {
        ItemDetailView(item: PantryItem(name: "Banana", catalogID: "banana", category: .fruit, storage: .counter,
                                        quantity: 4, expiresAt: .now.addingTimeInterval(86_400 * 2), price: 30))
    }
    .environment(AppServices.preview)
    .modelContainer(SampleData.previewContainer)
}
