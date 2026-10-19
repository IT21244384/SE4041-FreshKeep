import SwiftUI
import SwiftData
import FreshKeepCore

/// Main glass window: pantry list on the left, item details on the right,
/// and an ornament that launches the spatial experiences.
struct ContentView: View {
    @Environment(SpatialAppModel.self) private var appModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Query(filter: #Predicate<PantryItem> { $0.statusRaw == "active" }, sort: \PantryItem.expiresAt)
    private var items: [PantryItem]

    var body: some View {
        @Bindable var appModel = appModel
        NavigationSplitView {
            List(selection: $appModel.selectedItemID) {
                ForEach(FreshnessLevel.allCases, id: \.self) { level in
                    let group = items.filter { $0.freshness().level == level }
                    if !group.isEmpty {
                        Section(level.title) {
                            ForEach(group) { item in
                                SpatialRow(item: item).tag(item.id)
                            }
                        }
                    }
                }
            }
            .navigationTitle("FreshKeep")
        } detail: {
            if let item = items.first(where: { $0.id == appModel.selectedItemID }) {
                SpatialItemDetail(item: item)
            } else {
                ContentUnavailableView("Pick an item", systemImage: "hand.tap",
                                       description: Text("Or open the 3D fridge to see your whole pantry at once."))
            }
        }
        .ornament(attachmentAnchor: .scene(.bottom)) {
            HStack(spacing: 16) {
                Button {
                    openWindow(id: SceneID.fridge)
                } label: {
                    Label("Open 3D Fridge", systemImage: "refrigerator")
                }
                Button {
                    Task { await toggleTimeline() }
                } label: {
                    Label(appModel.isTimelineOpen ? "Exit Timeline" : "Expiry Timeline",
                          systemImage: appModel.isTimelineOpen ? "xmark.circle" : "clock.arrow.circlepath")
                }
                Divider().frame(height: 30)
                Label("\(items.filter { $0.freshness().level <= .useSoon }.count) need attention",
                      systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
            .padding()
            .glassBackgroundEffect()
        }
        .task { await runDemoIfRequested() }
    }

    /// `-demo` launch argument: a hands-free tour used to record the demo video in CI,
    /// since the simulator recording cannot perform gaze-and-pinch gestures.
    private func runDemoIfRequested() async {
        guard ProcessInfo.processInfo.arguments.contains("-demo"), !appModel.demoStarted else { return }
        appModel.demoStarted = true
        try? await Task.sleep(for: .seconds(4))
        appModel.selectedItemID = items.first?.id
        try? await Task.sleep(for: .seconds(6))
        // The fridge opens front and centre; the window steps aside so the volume is in view.
        // FridgeVolumeView continues the tour (inspect, cook, timeline) and reopens this window.
        openWindow(id: SceneID.fridge)
        try? await Task.sleep(for: .seconds(2))
        dismissWindow(id: SceneID.main)
    }

    private func toggleTimeline() async {
        if appModel.isTimelineOpen {
            await dismissImmersiveSpace()
            appModel.isTimelineOpen = false
        } else if case .opened = await openImmersiveSpace(id: SceneID.timeline) {
            appModel.isTimelineOpen = true
        }
    }
}

private struct SpatialRow: View {
    let item: PantryItem

    var body: some View {
        let freshness = item.freshness()
        HStack(spacing: 14) {
            Text(item.emoji).font(.largeTitle)
            VStack(alignment: .leading) {
                Text(item.name).font(.headline)
                Text(freshness.summary).font(.subheadline).foregroundStyle(Color(freshness.level.colorName))
            }
            Spacer()
            Image(systemName: item.storage.symbolName).foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        // Gaze highlights the row (system hover effect).
        .hoverEffect()
    }
}

struct SpatialItemDetail: View {
    @Bindable var item: PantryItem

    var body: some View {
        let freshness = item.freshness()
        let recipes = RecipeSuggester().suggestions(available: [item.profile?.id ?? "": freshness.daysLeft], limit: 3)
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 24) {
                    Text(item.emoji).font(.system(size: 120))
                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.name).font(.extraLargeTitle)
                        Text(freshness.summary)
                            .font(.title2)
                            .foregroundStyle(Color(freshness.level.colorName))
                        Text("\(item.storage.displayName) · ×\(item.quantity)").foregroundStyle(.secondary)
                    }
                }
                if let tip = item.profile?.storageTip {
                    Label(tip, systemImage: "lightbulb").padding().glassBackgroundEffect(in: .rect(cornerRadius: 20))
                }
                if !recipes.isEmpty {
                    Text("Use it up").font(.title3.bold())
                    HStack {
                        ForEach(recipes) { suggestion in
                            VStack(spacing: 8) {
                                Text(suggestion.recipe.emoji).font(.system(size: 48))
                                Text(suggestion.recipe.title).font(.headline).multilineTextAlignment(.center)
                                Text("\(suggestion.recipe.minutes) min").font(.caption).foregroundStyle(.secondary)
                            }
                            .frame(width: 180, height: 160)
                            .glassBackgroundEffect(in: .rect(cornerRadius: 24))
                            .hoverEffect(.lift)
                        }
                    }
                }
                HStack(spacing: 16) {
                    Button { withAnimation { item.resolve(as: .eaten) } } label: { Label("I ate it", systemImage: "checkmark.circle.fill") }
                        .tint(.green)
                    Button { withAnimation { _ = item.freeze() } } label: { Label("Freeze", systemImage: "snowflake") }
                        .disabled(item.storage == .freezer)
                    Button { withAnimation { item.resolve(as: .wasted) } } label: { Label("Wasted", systemImage: "xmark.bin") }
                        .tint(.orange)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.extraLarge)
            }
            .padding(40)
        }
    }
}
