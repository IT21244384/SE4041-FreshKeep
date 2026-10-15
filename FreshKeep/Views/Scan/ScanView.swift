import SwiftUI
import PhotosUI
import FreshKeepCore

/// Snap or pick a photo; on-device Vision recognises the food (or reads the
/// best-before date) and pre-fills a new pantry item.
struct ScanView: View {
    var onSaved: () -> Void = {}

    @Environment(AppServices.self) private var services
    @State private var model: ScanViewModel?
    @State private var pickerItem: PhotosPickerItem?
    @State private var showingCamera = false
    @State private var draft: ItemDraft?

    var body: some View {
        NavigationStack {
            Group {
                if let model {
                    ScanContent(model: model, pickerItem: $pickerItem, showingCamera: $showingCamera) { draft = $0 }
                } else {
                    ProgressView()
                }
            }
            .background(Color.appBackground)
            .navigationTitle("Scan")
            .toolbar {
                if model?.image != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Clear") { withAnimation { model?.reset() } }
                    }
                }
            }
            .fullScreenCover(isPresented: $showingCamera) {
                CameraPicker { model?.analyze($0) }
                    .ignoresSafeArea()
            }
            .sheet(item: $draft) { draft in
                AddEditItemView(mode: .create(draft)) {
                    model?.reset()
                    onSaved()
                }
            }
            .onChange(of: pickerItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = ImagePipeline.downsample(data: data, maxPixelSize: 1600) {
                        model?.analyze(image)
                    }
                    pickerItem = nil
                }
            }
        }
        .task {
            if model == nil {
                model = ScanViewModel(classifier: services.classifier, labelReader: services.labelReader)
            }
        }
    }
}

extension ItemDraft: Identifiable {
    var id: String { "\(name)-\(catalogID ?? "")-\(expiresAt.timeIntervalSince1970)" }
}

private struct ScanContent: View {
    let model: ScanViewModel
    @Binding var pickerItem: PhotosPickerItem?
    @Binding var showingCamera: Bool
    var onCreate: (ItemDraft) -> Void

    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        // Landscape iPhone: photo and results side by side.
        let layout = verticalSizeClass == .compact
            ? AnyLayout(HStackLayout(alignment: .top, spacing: Spacing.l))
            : AnyLayout(VStackLayout(spacing: Spacing.l))

        ScrollView {
            VStack(spacing: Spacing.l) {
                Picker("Scan mode", selection: Binding(get: { model.mode }, set: { mode in withAnimation { model.setMode(mode) } })) {
                    ForEach(ScanViewModel.Mode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("scan.mode")

                layout {
                    viewfinder
                    VStack(spacing: Spacing.l) {
                        captureButtons
                        results
                    }
                }
            }
            .padding()
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .sensoryFeedback(.success, trigger: model.phase) { _, new in
            if case .foods = new { return true }
            if case .label(let scan) = new { return scan.expiryDate != nil }
            return false
        }
    }

    private var viewfinder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.brandGradient)
            if let image = model.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
                    .accessibilityLabel("Selected photo")
            } else {
                VStack(spacing: Spacing.m) {
                    Image(systemName: model.mode == .food ? "camera.macro" : "text.viewfinder")
                        .font(.system(size: 56, weight: .semibold))
                        .symbolEffect(.pulse)
                    Text(model.mode == .food ? "Point at fruit, veg or groceries" : "Photograph the best-before date")
                        .font(.rounded(.headline))
                        .multilineTextAlignment(.center)
                }
                .foregroundStyle(.white)
                .padding()
            }
            ScanningOverlay(isScanning: model.isAnalyzing)
        }
        .aspectRatio(4 / 3, contentMode: .fit)
        .frame(maxWidth: 520)
        .animation(.gentleSpring, value: model.image)
    }

    private var captureButtons: some View {
        HStack(spacing: Spacing.m) {
            Button { showingCamera = true } label: {
                Label("Camera", systemImage: "camera.fill")
            }
            .buttonStyle(.primary)
            .disabled(!CameraPicker.isAvailable)

            PhotosPicker(selection: $pickerItem, matching: .images) {
                Label("Photos", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.soft)
            .accessibilityIdentifier("scan.photos")
        }
    }

    @ViewBuilder
    private var results: some View {
        switch model.phase {
        case .idle:
            if !CameraPicker.isAvailable {
                Text("No camera on this device — choose a photo instead.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            #if DEBUG
            // Simulator has no camera; this lets the demo and UI tests exercise the AI flow.
            Button("Try a sample photo") { model.analyze(SamplePhoto.make(for: model.mode)) }
                .font(.rounded(.subheadline, weight: .semibold))
                .accessibilityIdentifier("scan.sample")
            #endif
        case .analyzing:
            HStack(spacing: Spacing.s) {
                ProgressView()
                Text(model.mode == .food ? "Recognising food on device…" : "Reading label…")
                    .font(.rounded(.subheadline)).foregroundStyle(.secondary)
            }
            .padding()
        case .foods(let matches):
            VStack(alignment: .leading, spacing: Spacing.m) {
                Text("Is it one of these?").font(.rounded(.title3, weight: .bold))
                ForEach(Array(matches.enumerated()), id: \.element.id) { index, match in
                    MatchRow(match: match, rank: index) { onCreate(model.draft(for: match)) }
                }
                Button("None of these — add manually") { onCreate(ItemDraft(category: .fruit, photoData: model.photoData)) }
                    .font(.rounded(.subheadline))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .noFood:
            ContentUnavailableView {
                Label("No food spotted", systemImage: "eye.slash")
            } description: {
                Text("Try a closer photo in good light, or add the item manually.")
            } actions: {
                Button("Add manually") { onCreate(ItemDraft(category: .fruit, photoData: model.photoData)) }
            }
        case .label(let scan):
            LabelResult(scan: scan) { onCreate(model.draft(for: scan)) }
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.orange)
        }
    }
}

/// One recognised food with an animated confidence bar.
private struct MatchRow: View {
    let match: FoodMatch
    let rank: Int
    var onSelect: () -> Void

    @State private var shownConfidence: Double = 0

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: Spacing.m) {
                Text(match.emoji).font(.system(size: 36))
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(match.displayName).font(.rounded(.headline))
                        Spacer()
                        Text(match.confidence.formatted(.percent.precision(.fractionLength(0))))
                            .font(.rounded(.subheadline, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    GeometryReader { proxy in
                        Capsule().fill(Color.brand.opacity(0.15))
                            .overlay(alignment: .leading) {
                                Capsule().fill(Color.brand.gradient)
                                    .frame(width: proxy.size.width * shownConfidence)
                            }
                    }
                    .frame(height: 8)
                    if let profile = match.profile {
                        Text("Keeps ~\(profile.shelfLifeDays(in: profile.recommendedStorage)) days in the \(profile.recommendedStorage.displayName.lowercased())")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Image(systemName: "plus.circle.fill").font(.title2).foregroundStyle(Color.brand)
            }
            .freshCard(padding: Spacing.m)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(match.displayName), \(Int(match.confidence * 100)) percent confidence")
        .accessibilityHint("Adds it to your pantry")
        .accessibilityIdentifier("scan.match.\(match.id)")
        .onAppear {
            withAnimation(.easeOut(duration: 0.7).delay(Double(rank) * 0.12)) { shownConfidence = match.confidence }
        }
    }
}

private struct LabelResult: View {
    let scan: LabelScan
    var onUse: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            if let date = scan.expiryDate {
                Label("Best before \(date.formatted(date: .long, time: .omitted))", systemImage: "calendar.badge.checkmark")
                    .font(.rounded(.title3, weight: .bold))
                    .foregroundStyle(Color.brand)
                Button("Add item with this date", action: onUse)
                    .buttonStyle(.primary)
                    .accessibilityIdentifier("scan.useDate")
            } else {
                Label("No date found", systemImage: "calendar.badge.exclamationmark")
                    .font(.rounded(.title3, weight: .bold))
                    .foregroundStyle(.orange)
            }
            if !scan.recognizedText.isEmpty {
                DisclosureGroup("Text we read") {
                    Text(scan.recognizedText)
                        .font(.system(.footnote, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .freshCard()
    }
}

#if DEBUG
/// Sample photos so the scan flow can be demoed without a camera (Simulator).
/// Real photos dropped into `FreshKeep/Resources/DemoPhotos` (named `demo-food-*.jpg`
/// or `demo-label-*.jpg`) are used first, cycling on each tap; otherwise a drawn
/// stand-in image is generated.
enum SamplePhoto {
    private static var counter = 0

    static func make(for mode: ScanViewModel.Mode) -> UIImage {
        let prefix = mode == .food ? "demo-food-" : "demo-label-"
        let photos = ["jpg", "jpeg", "png"]
            .flatMap { Bundle.main.paths(forResourcesOfType: $0, inDirectory: nil) }
            .filter { ($0 as NSString).lastPathComponent.hasPrefix(prefix) }
            .sorted()
        if !photos.isEmpty, let image = UIImage(contentsOfFile: photos[counter % photos.count]) {
            counter += 1
            return image
        }
        return drawn(for: mode)
    }

    private static func drawn(for mode: ScanViewModel.Mode) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 800, height: 600))
        return renderer.image { context in
            UIColor(red: 0.98, green: 0.95, blue: 0.86, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 800, height: 600))
            let text: String = mode == .food ? "🍌" : "USE BY\n21 OCT 2026"
            let font = mode == .food ? UIFont.systemFont(ofSize: 360) : UIFont.monospacedSystemFont(ofSize: 80, weight: .bold)
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            let attributes: [NSAttributedString.Key: Any] = [.font: font, .paragraphStyle: paragraph, .foregroundColor: UIColor.black]
            let size = (text as NSString).boundingRect(with: CGSize(width: 800, height: 600), options: .usesLineFragmentOrigin,
                                                       attributes: attributes, context: nil).size
            (text as NSString).draw(in: CGRect(x: 0, y: (600 - size.height) / 2, width: 800, height: size.height),
                                    withAttributes: attributes)
        }
    }
}
#endif

#Preview {
    ScanView()
        .environment(AppServices.preview)
        .modelContainer(SampleData.previewContainer)
}
