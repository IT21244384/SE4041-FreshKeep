import SwiftUI
import SwiftData
import RealityKit
import FreshKeepCore

/// Mixed-reality "expiry timeline": items float on an arc around the user in their
/// real kitchen. Distance encodes time — what expires soonest is closest and at the
/// centre, so the most urgent food is literally right in front of you.
struct TimelineImmersiveView: View {
    @Environment(SpatialAppModel.self) private var appModel
    @Query(filter: #Predicate<PantryItem> { $0.statusRaw == "active" }, sort: \PantryItem.expiresAt)
    private var items: [PantryItem]

    var body: some View {
        RealityView { content, attachments in
            let anchor = Entity()
            anchor.name = "timeline"
            // Eye level, in front of the user.
            anchor.position = [0, 1.3, 0]
            content.add(anchor)

            for (index, item) in items.prefix(14).enumerated() {
                let position = Self.position(for: item, index: index)
                let token = SpatialFactory.makeToken(for: item)
                token.position = position
                token.scale = [1.6, 1.6, 1.6]
                anchor.addChild(token)

                if let label = attachments.entity(for: item.id) {
                    label.position = position + [0, 0.09, 0]
                    anchor.addChild(label)
                }
            }
            if let header = attachments.entity(for: "header") {
                header.position = [0, 0.45, -1.4]
                anchor.addChild(header)
            }
        } attachments: {
            Attachment(id: "header") {
                VStack(spacing: 6) {
                    Text("Expiry Timeline").font(.extraLargeTitle2)
                    Text("Closer = expires sooner. Pinch an item to select it.")
                        .font(.title3).foregroundStyle(.secondary)
                }
                .padding(28)
                .glassBackgroundEffect()
            }
            ForEach(items.prefix(14)) { item in
                Attachment(id: item.id) {
                    let freshness = item.freshness()
                    VStack(spacing: 2) {
                        Text("\(item.emoji) \(item.name)").font(.headline)
                        Text(freshness.summary).font(.caption).foregroundStyle(Color(freshness.level.colorName))
                    }
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .glassBackgroundEffect()
                }
            }
        }
        .gesture(
            SpatialTapGesture()
                .targetedToAnyEntity()
                .onEnded { value in
                    if let id = UUID(uuidString: value.entity.name) {
                        appModel.selectedItemID = id
                        // Pulse the selected token.
                        let entity = value.entity
                        let original = entity.transform
                        var bigger = original
                        bigger.scale *= 1.3
                        entity.move(to: bigger, relativeTo: entity.parent, duration: 0.15)
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(160))
                            entity.move(to: original, relativeTo: entity.parent, duration: 0.2)
                        }
                    }
                }
        )
        .onAppear { appModel.isTimelineOpen = true }
        .onDisappear { appModel.isTimelineOpen = false }
    }

    /// Spreads items across a 150° arc; days left push items further away (0.8 m – 2.2 m).
    static func position(for item: PantryItem, index: Int) -> SIMD3<Float> {
        let days = Float(max(item.freshness().daysLeft, -1) + 1)
        let distance = 0.8 + min(days, 14) / 14 * 1.4
        // Alternate left/right so the most urgent stays near the centre.
        let step = Float((index + 1) / 2) * (index.isMultiple(of: 2) ? 1 : -1)
        let angle = step * (.pi / 14)
        let height = Float(index % 3) * 0.12 - 0.12
        return [sin(angle) * distance, height, -cos(angle) * distance]
    }
}
