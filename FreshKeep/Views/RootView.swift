import SwiftUI

enum AppTab: String, CaseIterable, Identifiable, Hashable {
    case pantry, scan, insights, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pantry: "Pantry"
        case .scan: "Scan"
        case .insights: "Insights"
        case .settings: "Settings"
        }
    }

    var symbol: String {
        switch self {
        case .pantry: "refrigerator"
        case .scan: "camera.viewfinder"
        case .insights: "chart.bar.xaxis"
        case .settings: "gearshape"
        }
    }
}

/// Adaptive root: a tab bar on iPhone (compact width) and a sidebar on iPad / large
/// landscape (regular width). Each section owns its own NavigationStack.
struct RootView: View {
    @AppStorage(AppSettings.hasOnboardedKey) private var hasOnboarded = false
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var selection: AppTab = .pantry

    var body: some View {
        Group {
            if sizeClass == .regular {
                NavigationSplitView {
                    List(AppTab.allCases, selection: sidebarSelection) { tab in
                        Label(tab.title, systemImage: tab.symbol).tag(tab)
                    }
                    .navigationTitle("FreshKeep")
                } detail: {
                    content(for: selection)
                }
            } else {
                TabView(selection: $selection) {
                    ForEach(AppTab.allCases) { tab in
                        content(for: tab)
                            .tabItem { Label(tab.title, systemImage: tab.symbol) }
                            .tag(tab)
                    }
                }
            }
        }
        .fullScreenCover(isPresented: Binding(get: { !hasOnboarded }, set: { hasOnboarded = !$0 })) {
            OnboardingView { hasOnboarded = true }
        }
    }

    /// List selection is optional; ignore deselection so a section is always shown.
    private var sidebarSelection: Binding<AppTab?> {
        Binding(get: { selection }, set: { if let tab = $0 { selection = tab } })
    }

    @ViewBuilder
    private func content(for tab: AppTab) -> some View {
        switch tab {
        case .pantry: PantryListView(onScan: { selection = .scan })
        case .scan: ScanView(onSaved: { selection = .pantry })
        case .insights: InsightsView()
        case .settings: SettingsView()
        }
    }
}

#Preview {
    RootView()
        .environment(AppServices.preview)
        .modelContainer(SampleData.previewContainer)
}
