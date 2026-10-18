import SwiftUI
import SwiftData
import RealityKit

/// FreshKeep Spatial — the visionOS prototype (Assignment Part B).
///
/// Scenes:
///  - "main": a glass window with the pantry list and controls.
///  - "fridge": a volumetric window showing the pantry as 3D items on shelves.
///    Look + pinch to inspect an item; drag it into the cooking pot to use it up.
///  - "timeline": a mixed immersive space that lays items on an arc around the
///    user — the closer an item floats, the sooner it expires.
@main
struct FreshKeepSpatialApp: App {
    @State private var appModel = SpatialAppModel()
    private let container: ModelContainer

    init() {
        ItemTokenComponent.registerComponent()
        container = try! ModelContainer(for: PantryItem.self)
        MainActor.assumeIsolated {
            let context = container.mainContext
            // The prototype opens with a demo pantry so it can be shown straight away.
            if (try? context.fetchCount(FetchDescriptor<PantryItem>())) ?? 0 == 0 {
                SampleData.insert(into: context)
            }
        }
    }

    var body: some SwiftUI.Scene {
        WindowGroup(id: SceneID.main) {
            ContentView()
                .environment(appModel)
        }
        .defaultSize(width: 1100, height: 720)
        .modelContainer(container)

        WindowGroup(id: SceneID.fridge) {
            FridgeVolumeView()
                .environment(appModel)
        }
        .windowStyle(.volumetric)
        .defaultSize(width: 1.0, height: 0.75, depth: 0.5, in: .meters)
        // Open beside the main window instead of on top of it.
        .defaultWindowPlacement { _, context in
            // In the recorded demo the fridge takes centre stage.
            if ProcessInfo.processInfo.arguments.contains("-demo") { return WindowPlacement() }
            if let main = context.windows.first(where: { $0.id == SceneID.main }) {
                return WindowPlacement(.trailing(main))
            }
            return WindowPlacement()
        }
        .modelContainer(container)

        ImmersiveSpace(id: SceneID.timeline) {
            TimelineImmersiveView()
                .environment(appModel)
        }
        .modelContainer(container)
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}

enum SceneID {
    static let main = "main"
    static let fridge = "fridge"
    static let timeline = "timeline"
}

/// State shared between the window, the volume and the immersive space.
@Observable
final class SpatialAppModel {
    var selectedItemID: UUID?
    var isTimelineOpen = false
    var isFridgeOpen = false
    /// Last item dropped into the pot, used to show a recipe idea.
    var lastCookedName: String?
    /// Guards so the `-demo` tour runs once even if a scene reappears.
    var demoStarted = false
    var fridgeDemoStarted = false
}
