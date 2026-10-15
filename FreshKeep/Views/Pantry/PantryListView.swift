import SwiftUI
import SwiftData
import FreshKeepCore

enum PantrySort: String, CaseIterable, Identifiable {
    case expiry, name, recent
    var id: String { rawValue }
    var title: String {
        switch self {
        case .expiry: "Expiry date"
        case .name: "Name"
        case .recent: "Recently added"
        }
    }
}

/// Home screen: everything in the pantry grouped by how urgent it is.
struct PantryListView: View {
    var onScan: () -> Void = {}

    @Environment(\.modelContext) private var context
    @Environment(AppServices.self) private var services
    @Query(filter: #Predicate<PantryItem> { $0.statusRaw == "active" }, sort: \PantryItem.expiresAt)
    private var items: [PantryItem]

    @State private var path = NavigationPath()
    @State private var searchText = ""
    @State private var storageFilter: StorageLocation?
    @State private var sort: PantrySort = .expiry
    @State private var showingAdd = false
    @State private var confettiTrigger = 0
    @State private var toast: String?

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if items.isEmpty {
                    emptyState
                } else {
                    Section {
                        UrgentCarousel(items: urgentItems) { path.append($0) }
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                        StorageFilterBar(selection: $storageFilter, counts: storageCounts)
                            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                            .listRowBackground(Color.clear)
                    }
                    if filteredItems.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                            .listRowBackground(Color.clear)
                    }
                    ForEach(sections) { section in
                        Section {
                            ForEach(section.items) { item in
                                NavigationLink(value: item) {
                                    PantryRow(item: item)
                                }
                                .accessibilityIdentifier("pantry.row.\(item.name)")
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button { resolve(item, as: .eaten) } label: {
                                        Label("Eaten", systemImage: "checkmark.circle.fill")
                                    }
                                    .tint(.brand)
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) { delete(item) } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    Button { resolve(item, as: .wasted) } label: {
                                        Label("Wasted", systemImage: "xmark.bin.fill")
                                    }
                                    .tint(.orange)
                                }
                                .contextMenu {
                                    contextMenu(for: item)
                                } preview: {
                                    ItemPreviewCard(item: item)
                                }
                            }
                        } header: {
                            SectionHeader(level: section.level, count: section.items.count)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .animation(.snappySpring, value: filteredItems.map(\.id))
            .navigationTitle("My Pantry")
            .searchable(text: $searchText, prompt: "Search food")
            .toolbar { toolbar }
            .navigationDestination(for: PantryItem.self) { item in
                ItemDetailView(item: item)
            }
            .sheet(isPresented: $showingAdd) {
                AddEditItemView(mode: .create(ItemDraft()))
            }
            .overlay { ConfettiBurst(trigger: confettiTrigger) }
            .overlay(alignment: .bottom) { ToastView(message: $toast) }
            .sensoryFeedback(.success, trigger: confettiTrigger)
        }
    }

    // MARK: - Derived data

    private var filteredItems: [PantryItem] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        let filtered = items.filter { item in
            (storageFilter == nil || item.storage == storageFilter)
                && (query.isEmpty || item.name.localizedCaseInsensitiveContains(query)
                    || item.category.displayName.localizedCaseInsensitiveContains(query))
        }
        switch sort {
        case .expiry: return filtered
        case .name: return filtered.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        case .recent: return filtered.sorted { $0.addedAt > $1.addedAt }
        }
    }

    private var sections: [PantrySection] {
        let grouped = Dictionary(grouping: filteredItems) { $0.freshness().level }
        return FreshnessLevel.allCases.compactMap { level in
            guard let items = grouped[level], !items.isEmpty else { return nil }
            return PantrySection(level: level, items: items)
        }
    }

    private var urgentItems: [PantryItem] {
        items.filter { $0.freshness().level <= .useSoon }
    }

    private var storageCounts: [StorageLocation: Int] {
        Dictionary(grouping: items, by: \.storage).mapValues(\.count)
    }

    // MARK: - Actions

    private func resolve(_ item: PantryItem, as status: ItemStatus) {
        withAnimation(.snappySpring) { item.resolve(as: status) }
        services.notifications.cancel(itemID: item.id)
        withAnimation(.snappySpring) {
            if status == .eaten {
                confettiTrigger += 1
                toast = "Nice! \(item.name) rescued 🎉"
            } else {
                toast = "\(item.name) logged as wasted"
            }
        }
    }

    private func delete(_ item: PantryItem) {
        services.notifications.cancel(itemID: item.id)
        withAnimation { context.delete(item) }
    }

    private func freeze(_ item: PantryItem) {
        if item.freeze() {
            services.notifications.schedule(itemID: item.id, name: item.name, expiresAt: item.expiresAt)
            toast = "\(item.name) moved to the freezer ❄️"
        } else {
            toast = "Freezing won't extend \(item.name)"
        }
    }

    @ViewBuilder
    private func contextMenu(for item: PantryItem) -> some View {
        Button { resolve(item, as: .eaten) } label: { Label("Mark as eaten", systemImage: "checkmark.circle") }
        Button { freeze(item) } label: { Label("Freeze it", systemImage: "snowflake") }
        Button { resolve(item, as: .wasted) } label: { Label("Mark as wasted", systemImage: "xmark.bin") }
        Divider()
        Button(role: .destructive) { delete(item) } label: { Label("Delete", systemImage: "trash") }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Menu {
                Picker("Sort by", selection: $sort) {
                    ForEach(PantrySort.allCases) { Text($0.title).tag($0) }
                }
            } label: {
                Label("Sort", systemImage: "arrow.up.arrow.down.circle")
            }
        }
        ToolbarItem(placement: .primaryAction) {
            Button { showingAdd = true } label: {
                Label("Add item", systemImage: "plus.circle.fill")
            }
            .accessibilityIdentifier("pantry.add")
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Your pantry is empty", systemImage: "refrigerator")
        } description: {
            Text("Scan your groceries or add them by hand to start tracking freshness.")
        } actions: {
            Button("Scan food", action: onScan)
                .buttonStyle(.borderedProminent)
            Button("Add manually") { showingAdd = true }
        }
        .listRowBackground(Color.clear)
    }
}

// MARK: - Subviews

private struct PantrySection: Identifiable {
    let level: FreshnessLevel
    let items: [PantryItem]
    var id: Int { level.rawValue }
}

private struct SectionHeader: View {
    let level: FreshnessLevel
    let count: Int

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(Color.freshness(level)).frame(width: 8, height: 8)
            Text(level.title)
            Text("\(count)").foregroundStyle(.secondary)
        }
        .font(.rounded(.subheadline, weight: .semibold))
        .textCase(nil)
        .accessibilityElement(children: .combine)
    }
}

struct PantryRow: View {
    let item: PantryItem

    var body: some View {
        let freshness = item.freshness()
        HStack(spacing: Spacing.m) {
            ItemThumbnail(item: item)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.rounded(.headline))
                HStack(spacing: 4) {
                    Image(systemName: item.storage.symbolName)
                    Text(item.storage.displayName)
                    if item.quantity > 1 { Text("· ×\(item.quantity)") }
                }
                .font(.rounded(.caption))
                .foregroundStyle(.secondary)
                Text(freshness.summary)
                    .font(.rounded(.subheadline, weight: .medium))
                    .foregroundStyle(Color.freshness(freshness.level))
            }
            Spacer(minLength: 0)
            FreshnessRing(freshness: freshness, size: 40, lineWidth: 5)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

/// Horizontally paged cards for items that need attention, with a scroll transition.
private struct UrgentCarousel: View {
    let items: [PantryItem]
    var onSelect: (PantryItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack {
                Label(items.isEmpty ? "All fresh!" : "Needs attention", systemImage: items.isEmpty ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .font(.rounded(.title3, weight: .bold))
                    .foregroundStyle(items.isEmpty ? Color.brand : Color.primary)
                Spacer()
                if !items.isEmpty {
                    Text("\(items.count)")
                        .font(.rounded(.subheadline, weight: .bold))
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Color.freshness(.expiresToday).opacity(0.15), in: Capsule())
                        .foregroundStyle(Color.freshness(.expiresToday))
                }
            }
            .padding(.horizontal, Spacing.l)

            if items.isEmpty {
                Text("Nothing is about to expire. Great job!")
                    .font(.rounded(.subheadline))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, Spacing.l)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: Spacing.m) {
                        ForEach(items) { item in
                            Button { onSelect(item) } label: { UrgentCard(item: item) }
                                .buttonStyle(.plain)
                                .scrollTransition { content, phase in
                                    content
                                        .scaleEffect(phase.isIdentity ? 1 : 0.88)
                                        .opacity(phase.isIdentity ? 1 : 0.6)
                                        .rotation3DEffect(.degrees(phase.value * -12), axis: (x: 0, y: 1, z: 0))
                                }
                        }
                    }
                    .scrollTargetLayout()
                    .padding(.horizontal, Spacing.l)
                    .padding(.vertical, Spacing.s)
                }
                .scrollTargetBehavior(.viewAligned)
            }
        }
        .padding(.vertical, Spacing.s)
    }
}

private struct UrgentCard: View {
    let item: PantryItem

    var body: some View {
        let freshness = item.freshness()
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack {
                Text(item.emoji).font(.largeTitle)
                Spacer()
                FreshnessRing(freshness: freshness, size: 44, lineWidth: 5)
            }
            Text(item.name)
                .font(.rounded(.headline))
                .lineLimit(1)
            Text(freshness.summary)
                .font(.rounded(.caption, weight: .semibold))
                .foregroundStyle(Color.freshness(freshness.level))
        }
        .frame(width: 150, alignment: .leading)
        .freshCard(padding: Spacing.m)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens item details")
    }
}

private struct StorageFilterBar: View {
    @Binding var selection: StorageLocation?
    let counts: [StorageLocation: Int]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.s) {
                FilterChip(title: "All", systemImage: "square.grid.2x2", isSelected: selection == nil) {
                    withAnimation(.snappySpring) { selection = nil }
                }
                ForEach(StorageLocation.allCases) { location in
                    FilterChip(title: "\(location.displayName) \(counts[location] ?? 0)",
                               systemImage: location.symbolName, isSelected: selection == location) {
                        withAnimation(.snappySpring) { selection = selection == location ? nil : location }
                    }
                }
            }
            .padding(.horizontal, Spacing.l)
        }
    }
}

/// Larger card shown when long-pressing a row (context menu preview).
private struct ItemPreviewCard: View {
    let item: PantryItem

    var body: some View {
        let freshness = item.freshness()
        HStack(spacing: Spacing.l) {
            ItemThumbnail(item: item, size: 80)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name).font(.rounded(.title2, weight: .bold))
                Text(freshness.summary).foregroundStyle(Color.freshness(freshness.level))
                if let tip = item.profile?.storageTip {
                    Text(tip).font(.caption).foregroundStyle(.secondary).lineLimit(3)
                }
            }
            FreshnessRing(freshness: freshness, size: 64)
        }
        .padding()
        .frame(width: 340)
    }
}

/// Small transient message at the bottom of the screen.
struct ToastView: View {
    @Binding var message: String?

    var body: some View {
        if let message {
            Text(message)
                .font(.rounded(.subheadline, weight: .semibold))
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(.thinMaterial, in: Capsule())
                .shadow(radius: 6, y: 3)
                .padding(.bottom, 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .task(id: message) {
                    try? await Task.sleep(for: .seconds(2.2))
                    withAnimation { self.message = nil }
                }
                .accessibilityAddTraits(.isStaticText)
                .onAppear { UIAccessibility.post(notification: .announcement, argument: message) }
        }
    }
}

#Preview {
    PantryListView()
        .environment(AppServices.preview)
        .modelContainer(SampleData.previewContainer)
}
