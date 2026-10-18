import SwiftUI
import SwiftData
import RealityKit
import FreshKeepCore

/// Volumetric "virtual fridge". Each active item is a 3D token on the shelf for its
/// storage location, coloured by freshness. Interactions:
///  - look + pinch (spatial tap): shows a floating info card above the item;
///  - pinch + drag: pick an item up and drop it into the cooking pot to mark it eaten.
struct FridgeVolumeView: View {
    @Environment(SpatialAppModel.self) private var appModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Query(filter: #Predicate<PantryItem> { $0.statusRaw == "active" }, sort: \PantryItem.expiresAt)
    private var items: [PantryItem]

    @State private var root = Entity()
    @State private var selectedID: UUID?
    @State private var cookedMessage: String?
    /// Bumped to force a re-layout (e.g. to snap a dropped item back to its shelf).
    @State private var layoutVersion = 0

    private let potPosition = SIMD3<Float>(0.36, -0.26, 0.12)

    var body: some View {
        RealityView { content, attachments in
            root.name = "fridgeRoot"
            content.add(root)
            root.addChild(SpatialFactory.makeShelves())
            root.addChild(SpatialFactory.makePot(at: potPosition))
            if let title = attachments.entity(for: "title") {
                title.position = [0, 0.33, 0]
                root.addChild(title)
            }
            syncItems(attachments: attachments)
        } update: { _, attachments in
            _ = layoutVersion
            syncItems(attachments: attachments)
        } attachments: {
            Attachment(id: "title") {
                Text("My Fridge").font(.extraLargeTitle2).padding(.horizontal, 24).padding(.vertical, 8)
                    .glassBackgroundEffect()
            }
            if let selected = items.first(where: { $0.id == selectedID }) {
                Attachment(id: "card") {
                    ItemCard(item: selected) { selectedID = nil }
                }
            }
            if let cookedMessage {
                Attachment(id: "cooked") {
                    Label(cookedMessage, systemImage: "frying.pan.fill")
                        .font(.title3)
                        .padding()
                        .glassBackgroundEffect()
                }
            }
        }
        .gesture(tapGesture)
        .gesture(dragGesture)
        .task(id: cookedMessage) {
            guard cookedMessage != nil else { return }
            try? await Task.sleep(for: .seconds(3))
            cookedMessage = nil
        }
        .task { await runDemoIfRequested() }
        .onAppear { appModel.isFridgeOpen = true }
        .onDisappear { appModel.isFridgeOpen = false }
    }

    // MARK: - Scene sync

    /// Adds, moves and removes item entities so the 3D scene matches SwiftData.
    private func syncItems(attachments: RealityViewAttachments) {
        let itemsByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id.uuidString, $0) })

        // Remove entities for items that are no longer active.
        for child in root.children where child.components.has(ItemTokenComponent.self) {
            if itemsByID[child.name] == nil { child.removeFromParent() }
        }

        // Lay items out in a grid on their storage shelf.
        let grouped = Dictionary(grouping: items, by: \.storage)
        for storage in StorageLocation.allCases {
            for (index, item) in (grouped[storage] ?? []).enumerated() {
                let target = SpatialFactory.slotPosition(storage: storage, index: index)
                if let existing = root.children.first(where: { $0.name == item.id.uuidString }) {
                    if !existing.components[ItemTokenComponent.self]!.isDragging {
                        existing.move(to: Transform(scale: existing.scale, rotation: existing.orientation, translation: target),
                                      relativeTo: root, duration: 0.4, timingFunction: .easeInOut)
                    }
                    SpatialFactory.updateColor(of: existing, for: item)
                } else {
                    let token = SpatialFactory.makeToken(for: item)
                    token.position = target + [0, 0.25, 0]
                    root.addChild(token)
                    // Drop-in animation.
                    token.move(to: Transform(scale: token.scale, rotation: token.orientation, translation: target),
                               relativeTo: root, duration: 0.6, timingFunction: .easeOut)
                }
            }
        }

        // Floating card above the selected item.
        if let card = attachments.entity(for: "card"),
           let id = selectedID, let token = root.children.first(where: { $0.name == id.uuidString }) {
            card.position = token.position + [0, 0.14, 0.04]
            if card.parent == nil { root.addChild(card) }
        }
        if let cooked = attachments.entity(for: "cooked") {
            cooked.position = potPosition + [0, 0.15, 0]
            if cooked.parent == nil { root.addChild(cooked) }
        }
    }

    // MARK: - Gestures

    private var tapGesture: some Gesture {
        SpatialTapGesture()
            .targetedToAnyEntity()
            .onEnded { value in
                guard let id = UUID(uuidString: value.entity.name) else { return }
                selectedID = selectedID == id ? nil : id
                appModel.selectedItemID = id
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .targetedToAnyEntity()
            .onChanged { value in
                let entity = value.entity
                guard entity.components.has(ItemTokenComponent.self), let parent = entity.parent else { return }
                entity.components[ItemTokenComponent.self]?.isDragging = true
                entity.position = value.convert(value.location3D, from: .local, to: parent)
            }
            .onEnded { value in
                let entity = value.entity
                guard entity.components.has(ItemTokenComponent.self) else { return }
                entity.components[ItemTokenComponent.self]?.isDragging = false
                if simd_distance(entity.position, potPosition) < 0.14,
                   let item = items.first(where: { $0.id.uuidString == entity.name }) {
                    cook(item, entity: entity)
                } else {
                    // Not in the pot: snap back to its shelf slot.
                    layoutVersion += 1
                }
            }
    }

    /// `-demo` launch argument: inspect the most urgent item, carry it to the pot,
    /// show the expiry timeline, then bring the main window back.
    private func runDemoIfRequested() async {
        guard ProcessInfo.processInfo.arguments.contains("-demo"), !appModel.fridgeDemoStarted else { return }
        appModel.fridgeDemoStarted = true
        try? await Task.sleep(for: .seconds(4))
        guard let item = items.first else { return }
        selectedID = item.id
        try? await Task.sleep(for: .seconds(5))
        selectedID = nil
        if let entity = root.children.first(where: { $0.name == item.id.uuidString }) {
            // Lift the item and carry it over the pot, as a pinch-and-drag would.
            let lifted = Transform(scale: entity.scale, rotation: entity.orientation, translation: entity.position + [0, 0.12, 0.08])
            entity.move(to: lifted, relativeTo: root, duration: 0.8, timingFunction: .easeOut)
            try? await Task.sleep(for: .seconds(0.9))
            let overPot = Transform(scale: entity.scale, rotation: entity.orientation, translation: potPosition + [0, 0.14, 0])
            entity.move(to: overPot, relativeTo: root, duration: 1.4, timingFunction: .easeInOut)
            try? await Task.sleep(for: .seconds(1.6))
            cook(item, entity: entity)
        }
        try? await Task.sleep(for: .seconds(6))
        if case .opened = await openImmersiveSpace(id: SceneID.timeline) { appModel.isTimelineOpen = true }
        try? await Task.sleep(for: .seconds(16))
        await dismissImmersiveSpace()
        appModel.isTimelineOpen = false
        try? await Task.sleep(for: .seconds(1))
        openWindow(id: SceneID.main)
    }

    private func cook(_ item: PantryItem, entity: Entity) {
        // Shrink into the pot, then resolve the item.
        entity.move(to: Transform(scale: [0.01, 0.01, 0.01], rotation: entity.orientation, translation: potPosition),
                    relativeTo: entity.parent, duration: 0.35, timingFunction: .easeIn)
        let recipe = RecipeSuggester().suggestions(available: [item.profile?.id ?? "": item.freshness().daysLeft], limit: 1).first
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(380))
            withAnimation { item.resolve(as: .eaten) }
            if selectedID == item.id { selectedID = nil }
            cookedMessage = recipe.map { "\(item.name) rescued! Try \($0.recipe.title) \($0.recipe.emoji)" }
                ?? "\(item.name) rescued! 🎉"
            appModel.lastCookedName = item.name
        }
    }
}

/// Glass info card floating above a selected 3D item.
private struct ItemCard: View {
    @Bindable var item: PantryItem
    var onClose: () -> Void

    var body: some View {
        let freshness = item.freshness()
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\(item.emoji) \(item.name)").font(.title2.bold())
                Spacer()
                Button(action: onClose) { Image(systemName: "xmark") }
                    .buttonBorderShape(.circle)
            }
            Text(freshness.summary).foregroundStyle(Color(freshness.level.colorName)).font(.headline)
            Text("Drag me into the pot to cook me").font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("Eaten") { withAnimation { item.resolve(as: .eaten) }; onClose() }
                Button("Freeze") { withAnimation { _ = item.freeze() } }
                    .disabled(item.storage == .freezer)
            }
        }
        .padding(20)
        .frame(width: 320)
        .glassBackgroundEffect()
    }
}
