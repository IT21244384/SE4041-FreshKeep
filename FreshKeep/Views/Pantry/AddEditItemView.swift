import SwiftUI
import SwiftData
import PhotosUI
import FreshKeepCore

/// Form for adding a new item (blank, or pre-filled from a scan) or editing one.
struct AddEditItemView: View {
    enum Mode {
        case create(ItemDraft)
        case edit(PantryItem)
    }

    let mode: Mode
    var onSaved: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppServices.self) private var services

    @State private var draft: ItemDraft
    @State private var photoSelection: PhotosPickerItem?
    @State private var labelSelection: PhotosPickerItem?
    @State private var readingLabel = false
    @State private var labelMessage: String?
    @State private var shakeName: CGFloat = 0
    @FocusState private var nameFocused: Bool

    init(mode: Mode, onSaved: @escaping () -> Void = {}) {
        self.mode = mode
        self.onSaved = onSaved
        switch mode {
        case .create(let draft): _draft = State(initialValue: draft)
        case .edit(let item): _draft = State(initialValue: ItemDraft(item: item))
        }
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var suggestions: [FoodProfile] {
        guard nameFocused, draft.catalogID == nil else { return [] }
        return ShelfLifeCatalog.shared.search(draft.name, limit: 6)
    }

    var body: some View {
        NavigationStack {
            Form {
                photoSection
                foodSection
                expirySection
                detailsSection
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(isEditing ? "Edit item" : "Add item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                        .accessibilityIdentifier("item.save")
                }
            }
            .onChange(of: draft.storage) { _, _ in withAnimation { draft.reestimateExpiry() } }
            .onChange(of: draft.category) { _, _ in withAnimation { draft.reestimateExpiry() } }
            .onChange(of: photoSelection) { _, item in loadPhoto(item) }
            .onChange(of: labelSelection) { _, item in readLabel(item) }
        }
    }

    // MARK: - Sections

    private var photoSection: some View {
        Section {
            HStack(spacing: Spacing.l) {
                Group {
                    if let data = draft.photoData, let image = ImagePipeline.downsample(data: data, maxPixelSize: 240) {
                        Image(uiImage: image).resizable().scaledToFill()
                    } else {
                        Text(draft.profile?.emoji ?? "🍽️")
                            .font(.system(size: 40))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.brand.opacity(0.12))
                    }
                }
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                VStack(alignment: .leading, spacing: Spacing.s) {
                    PhotosPicker(selection: $photoSelection, matching: .images) {
                        Label(draft.photoData == nil ? "Add photo" : "Change photo", systemImage: "photo")
                    }
                    if draft.photoData != nil {
                        Button("Remove photo", role: .destructive) { withAnimation { draft.photoData = nil } }
                            .font(.subheadline)
                    }
                }
            }
        }
    }

    private var foodSection: some View {
        Section("Food") {
            TextField("Name (e.g. Bananas)", text: $draft.name)
                .focused($nameFocused)
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                .modifier(ShakeEffect(animatableData: shakeName))
                .onChange(of: draft.name) { _, newValue in
                    // Typing a different name detaches the catalog match.
                    if let profile = draft.profile, profile.name != newValue { draft.catalogID = nil }
                }
                .accessibilityIdentifier("item.name")

            if !suggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(suggestions) { profile in
                            Button {
                                withAnimation(.snappySpring) { draft.apply(profile) }
                                nameFocused = false
                            } label: {
                                Text("\(profile.emoji) \(profile.name)")
                                    .font(.rounded(.subheadline))
                                    .padding(.horizontal, 12).padding(.vertical, 6)
                                    .background(Color.brand.opacity(0.12), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .transition(.opacity)
            }

            Picker("Category", selection: $draft.category) {
                ForEach(FoodCategory.allCases) { category in
                    Label(category.displayName, systemImage: category.symbolName).tag(category)
                }
            }

            Picker("Stored in", selection: $draft.storage) {
                ForEach(StorageLocation.allCases) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.segmented)

            Stepper("Quantity: \(draft.quantity)", value: $draft.quantity, in: 1...99)
        }
    }

    private var expirySection: some View {
        Section {
            DatePicker("Expires", selection: Binding(
                get: { draft.expiresAt },
                set: { draft.expiresAt = $0; draft.expirySource = .manual }
            ), displayedComponents: .date)
            .accessibilityIdentifier("item.expiry")

            HStack {
                Image(systemName: draft.expirySource == .label ? "text.viewfinder" : "sparkles")
                    .foregroundStyle(Color.brand)
                Text(draft.expirySource == .estimated
                     ? "Estimated \(draft.estimatedShelfLifeDays) days in the \(draft.storage.displayName.lowercased())"
                     : draft.expirySource.label)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
                if draft.expirySource != .estimated {
                    Button("Use estimate") {
                        withAnimation {
                            draft.expirySource = .estimated
                            draft.reestimateExpiry()
                        }
                    }
                    .font(.footnote)
                }
            }

            PhotosPicker(selection: $labelSelection, matching: .images) {
                HStack {
                    Label("Read date from label photo", systemImage: "text.viewfinder")
                    if readingLabel { Spacer(); ProgressView() }
                }
            }
            .disabled(readingLabel)
            if let labelMessage {
                Text(labelMessage).font(.footnote).foregroundStyle(.secondary)
            }
        } header: {
            Text("Best before")
        } footer: {
            if let tip = draft.profile?.storageTip {
                Label(tip, systemImage: "lightbulb")
            }
        }
    }

    private var detailsSection: some View {
        Section("Details") {
            HStack {
                Text("Price (LKR)")
                Spacer()
                TextField("0", value: $draft.price, format: .number.precision(.fractionLength(0...2)))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 120)
            }
            TextField("Notes", text: $draft.notes, axis: .vertical)
                .lineLimit(1...4)
        }
    }

    // MARK: - Actions

    private func save() {
        guard draft.isValid else {
            withAnimation(.default) { shakeName += 1 }
            nameFocused = true
            return
        }
        let item: PantryItem
        switch mode {
        case .create:
            item = draft.makeItem()
            context.insert(item)
        case .edit(let existing):
            draft.apply(to: existing)
            item = existing
        }
        try? context.save()
        services.notifications.schedule(itemID: item.id, name: item.name, expiresAt: item.expiresAt)
        onSaved()
        dismiss()
    }

    private func loadPhoto(_ selection: PhotosPickerItem?) {
        guard let selection else { return }
        Task {
            if let data = try? await selection.loadTransferable(type: Data.self) {
                let stored = ImagePipeline.storageData(from: data)
                withAnimation { draft.photoData = stored }
            }
            photoSelection = nil
        }
    }

    private func readLabel(_ selection: PhotosPickerItem?) {
        guard let selection else { return }
        readingLabel = true
        labelMessage = nil
        Task {
            defer {
                readingLabel = false
                labelSelection = nil
            }
            guard let data = try? await selection.loadTransferable(type: Data.self),
                  let image = ImagePipeline.downsample(data: data, maxPixelSize: 2000),
                  let scan = try? await services.labelReader.read(image) else {
                labelMessage = "Couldn't read that photo."
                return
            }
            if let date = scan.expiryDate {
                withAnimation {
                    draft.expiresAt = date
                    draft.expirySource = .label
                }
                labelMessage = "Found \(date.formatted(date: .long, time: .omitted))"
            } else {
                labelMessage = "No date found. Try a closer, well-lit photo of the label."
            }
        }
    }
}

#Preview("Add") {
    AddEditItemView(mode: .create(ItemDraft(profile: ShelfLifeCatalog.shared.profile(named: "banana")!)))
        .environment(AppServices.preview)
        .modelContainer(SampleData.previewContainer)
}
