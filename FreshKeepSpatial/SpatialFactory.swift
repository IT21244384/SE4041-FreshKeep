import RealityKit
import UIKit
import FreshKeepCore

/// Marks an entity as a pantry item token and tracks whether it is being dragged.
struct ItemTokenComponent: Component {
    var isDragging = false
}

/// Builds the RealityKit entities used by the volume and the immersive space.
/// Everything is generated from primitives, so the prototype ships with no 3D assets.
@MainActor
enum SpatialFactory {
    static let shelfWidth: Float = 0.8
    static let shelfDepth: Float = 0.3
    static let columns = 6

    /// Shelf height for each storage location (top to bottom).
    static func shelfY(_ storage: StorageLocation) -> Float {
        switch storage {
        case .fridge: 0.12
        case .counter: -0.02
        case .pantry: -0.16
        case .freezer: -0.30
        }
    }

    static func slotPosition(storage: StorageLocation, index: Int) -> SIMD3<Float> {
        let column = index % columns
        let row = index / columns
        let spacing = (shelfWidth - 0.16) / Float(columns - 1)
        let x = -shelfWidth / 2 + 0.06 + Float(column) * spacing
        let z = -0.06 + Float(row) * 0.09
        return [x, shelfY(storage) + 0.035, z]
    }

    static func makeShelves() -> Entity {
        let shelves = Entity()
        shelves.name = "shelves"
        let glass = SimpleMaterial(color: UIColor.white.withAlphaComponent(0.35), roughness: 0.15, isMetallic: false)
        for storage in StorageLocation.allCases {
            let board = ModelEntity(mesh: .generateBox(width: shelfWidth, height: 0.012, depth: shelfDepth, cornerRadius: 0.004),
                                    materials: [glass])
            board.position = [0, shelfY(storage), 0]
            shelves.addChild(board)

            let label = ModelEntity(mesh: .generateText(storage.displayName.uppercased(), extrusionDepth: 0.002,
                                                        font: .systemFont(ofSize: 0.022, weight: .bold)),
                                    materials: [SimpleMaterial(color: .white, isMetallic: false)])
            label.position = [-shelfWidth / 2, shelfY(storage) - 0.032, shelfDepth / 2]
            shelves.addChild(label)
        }
        return shelves
    }

    /// The "cooking pot" drop target.
    static func makePot(at position: SIMD3<Float>) -> Entity {
        let pot = ModelEntity(mesh: .generateBox(width: 0.16, height: 0.09, depth: 0.16, cornerRadius: 0.04),
                              materials: [SimpleMaterial(color: UIColor(red: 0.85, green: 0.35, blue: 0.2, alpha: 1),
                                                         roughness: 0.4, isMetallic: true)])
        pot.name = "pot"
        pot.position = position
        let rim = ModelEntity(mesh: .generateBox(width: 0.17, height: 0.012, depth: 0.17, cornerRadius: 0.006),
                              materials: [SimpleMaterial(color: .darkGray, roughness: 0.3, isMetallic: true)])
        rim.position = [0, 0.045, 0]
        pot.addChild(rim)
        let label = ModelEntity(mesh: .generateText("COOK NOW", extrusionDepth: 0.002, font: .systemFont(ofSize: 0.02, weight: .heavy)),
                                materials: [SimpleMaterial(color: .white, isMetallic: false)])
        label.position = [-0.055, -0.075, 0.08]
        pot.addChild(label)
        return pot
    }

    static func color(for level: FreshnessLevel) -> UIColor {
        UIColor(named: level.colorName) ?? .systemGreen
    }

    /// A rounded token whose size follows quantity and colour follows freshness.
    static func makeToken(for item: PantryItem) -> ModelEntity {
        let freshness = item.freshness()
        let radius = Float(0.022 + min(Double(item.quantity), 6) * 0.003)
        let token = ModelEntity(mesh: .generateSphere(radius: radius),
                                materials: [material(for: freshness.level)])
        token.name = item.id.uuidString
        token.components.set(ItemTokenComponent())
        // Needed for gaze highlight, pinch and drag.
        token.components.set(InputTargetComponent())
        token.components.set(HoverEffectComponent())
        token.generateCollisionShapes(recursive: false)

        // Category initial floating on the token.
        let initial = ModelEntity(mesh: .generateText(String(item.name.prefix(1)).uppercased(), extrusionDepth: 0.001,
                                                      font: .systemFont(ofSize: CGFloat(radius) * 1.2, weight: .bold)),
                                  materials: [SimpleMaterial(color: .white, isMetallic: false)])
        initial.position = [-radius * 0.35, -radius * 0.4, radius * 0.95]
        token.addChild(initial)
        return token
    }

    static func updateColor(of entity: Entity, for item: PantryItem) {
        guard let model = entity as? ModelEntity else { return }
        model.model?.materials = [material(for: item.freshness().level)]
    }

    private static func material(for level: FreshnessLevel) -> SimpleMaterial {
        SimpleMaterial(color: color(for: level), roughness: level == .expired ? 0.9 : 0.25, isMetallic: false)
    }
}
