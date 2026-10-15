import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppServices.self) private var services
    @Query private var items: [PantryItem]

    @AppStorage(AppSettings.remindersEnabledKey) private var remindersEnabled = true
    @AppStorage(AppSettings.reminderLeadDaysKey) private var leadDays = 2
    @AppStorage(AppSettings.reminderHourKey) private var reminderHour = 9
    @AppStorage(AppSettings.useSoonThresholdKey) private var useSoonThreshold = 2
    @AppStorage(AppSettings.appearanceKey) private var appearance = Appearance.system.rawValue
    @AppStorage(AppSettings.hasOnboardedKey) private var hasOnboarded = true

    @State private var confirmErase = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Expiry reminders", isOn: $remindersEnabled)
                    if remindersEnabled {
                        Stepper("Remind me \(leadDays) day\(leadDays == 1 ? "" : "s") before", value: $leadDays, in: 1...7)
                        Picker("Reminder time", selection: $reminderHour) {
                            ForEach([7, 8, 9, 12, 17, 19], id: \.self) { hour in
                                Text(timeLabel(hour)).tag(hour)
                            }
                        }
                    }
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("Reminders are scheduled on your device. No account needed.")
                }

                Section("Freshness") {
                    Stepper("\"Use soon\" when \(useSoonThreshold) day\(useSoonThreshold == 1 ? "" : "s") left",
                            value: $useSoonThreshold, in: 1...5)
                }

                Section("Appearance") {
                    Picker("Theme", selection: $appearance) {
                        ForEach(Appearance.allCases) { Text($0.title).tag($0.rawValue) }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Data") {
                    LabeledContent("Items tracked", value: "\(items.count)")
                    Button("Load sample pantry") { SampleData.insert(into: context) }
                    Button("Show welcome screens again") { hasOnboarded = false }
                    Button("Erase all data", role: .destructive) { confirmErase = true }
                }

                Section("About") {
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    LabeledContent("Food recognition", value: "On-device (Vision)")
                    Text("FreshKeep was built for SE4041 Mobile Application Design & Development at SLIIT. Shelf-life guidance is approximate — always check food before eating.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .onChange(of: remindersEnabled) { _, enabled in rescheduleAll(enabled: enabled) }
            .onChange(of: leadDays) { _, _ in rescheduleAll(enabled: remindersEnabled) }
            .onChange(of: reminderHour) { _, _ in rescheduleAll(enabled: remindersEnabled) }
            .confirmationDialog("Erase everything?", isPresented: $confirmErase, titleVisibility: .visible) {
                Button("Erase all data", role: .destructive, action: eraseAll)
            } message: {
                Text("All items and history will be permanently removed from this device.")
            }
        }
    }

    private func timeLabel(_ hour: Int) -> String {
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: .now) ?? .now
        return date.formatted(date: .omitted, time: .shortened)
    }

    private func rescheduleAll(enabled: Bool) {
        services.notifications.cancelAll()
        guard enabled else { return }
        Task {
            guard await services.notifications.requestAuthorization() else { return }
            for item in items where item.status == .active {
                services.notifications.schedule(itemID: item.id, name: item.name, expiresAt: item.expiresAt)
            }
        }
    }

    private func eraseAll() {
        services.notifications.cancelAll()
        try? context.delete(model: PantryItem.self)
        try? context.save()
    }
}

#Preview {
    SettingsView()
        .environment(AppServices.preview)
        .modelContainer(SampleData.previewContainer)
}
