import SwiftUI
import SwiftData

@main
struct FreshKeepApp: App {
    /// Services are created once and injected through the environment so views
    /// and tests can swap them (e.g. a mock classifier for UI tests).
    @State private var services = AppServices.makeForLaunch()
    @AppStorage(AppSettings.appearanceKey) private var appearance = Appearance.system.rawValue

    private let container: ModelContainer

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        let inMemory = arguments.contains(LaunchArgument.uiTesting)
        do {
            container = try ModelContainer(for: PantryItem.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: inMemory))
        } catch {
            fatalError("Could not open the FreshKeep store: \(error)")
        }
        if inMemory {
            // UI tests start from a known state.
            let defaults = UserDefaults.standard
            defaults.set(arguments.contains(LaunchArgument.skipOnboarding), forKey: AppSettings.hasOnboardedKey)
            defaults.set(false, forKey: AppSettings.remindersEnabledKey)
        }
        if arguments.contains(LaunchArgument.seedSampleData) {
            MainActor.assumeIsolated { SampleData.insert(into: container.mainContext) }
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(services)
                .preferredColorScheme(Appearance(rawValue: appearance)?.colorScheme)
                .tint(.brand)
        }
        .modelContainer(container)
    }
}

/// Launch arguments understood by the app (used by UI tests and screenshots).
enum LaunchArgument {
    static let uiTesting = "-ui-testing"
    static let skipOnboarding = "-skip-onboarding"
    static let seedSampleData = "-seed-sample-data"
    static let mockClassifier = "-mock-classifier"
}

enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
