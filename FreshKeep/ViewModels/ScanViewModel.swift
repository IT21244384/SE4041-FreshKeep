import UIKit
import Observation
import FreshKeepCore

/// Drives the Scan screen: holds the chosen photo and runs Vision on it.
@MainActor
@Observable
final class ScanViewModel {
    enum Mode: String, CaseIterable, Identifiable {
        case food = "Food"
        case label = "Date label"
        var id: String { rawValue }
    }

    enum Phase: Equatable {
        case idle
        case analyzing
        case foods([FoodMatch])
        case noFood
        case label(LabelScan)
        case failed(String)
    }

    private(set) var mode: Mode = .food
    private(set) var phase: Phase = .idle
    private(set) var image: UIImage?
    /// Measured analysis time, shown in debug builds and logged for the report.
    private(set) var lastDuration: Duration?

    private let classifier: FoodClassifying
    private let labelReader: LabelReading
    private var task: Task<Void, Never>?

    init(classifier: FoodClassifying, labelReader: LabelReading) {
        self.classifier = classifier
        self.labelReader = labelReader
    }

    var isAnalyzing: Bool { phase == .analyzing }

    /// Analyses a newly chosen photo, cancelling any analysis still running.
    func analyze(_ newImage: UIImage) {
        task?.cancel()
        // Work on a downsampled copy: Vision only needs ~1000 px and this keeps memory low.
        let working = newImage.preparingThumbnail(of: newImage.size.fitting(maxSide: 1280)) ?? newImage
        image = working
        phase = .analyzing
        let mode = mode
        task = Task {
            let clock = ContinuousClock()
            let start = clock.now
            do {
                switch mode {
                case .food:
                    let matches = try await classifier.classify(working)
                    guard !Task.isCancelled else { return }
                    phase = matches.isEmpty ? .noFood : .foods(matches)
                case .label:
                    let scan = try await labelReader.read(working)
                    guard !Task.isCancelled else { return }
                    phase = .label(scan)
                }
            } catch is CancellationError {
                return
            } catch {
                phase = .failed(error.localizedDescription)
            }
            lastDuration = clock.now - start
        }
    }

    /// Switching between food and label scanning starts over.
    func setMode(_ newMode: Mode) {
        guard newMode != mode else { return }
        reset()
        mode = newMode
    }

    func reset() {
        task?.cancel()
        image = nil
        phase = .idle
    }

    /// JPEG data of the photo, downsized for storage with a new item.
    var photoData: Data? {
        image.flatMap { ImagePipeline.storageData(from: $0) }
    }

    func draft(for match: FoodMatch) -> ItemDraft {
        if let profile = match.profile {
            return ItemDraft(profile: profile, photoData: photoData)
        }
        return ItemDraft(category: match.category, photoData: photoData)
    }

    func draft(for scan: LabelScan) -> ItemDraft {
        var draft = ItemDraft()
        if let date = scan.expiryDate {
            draft.expiresAt = date
            draft.expirySource = .label
        }
        draft.photoData = photoData
        return draft
    }
}

extension CGSize {
    /// Size scaled down (never up) so the longest side is at most `maxSide`.
    func fitting(maxSide: CGFloat) -> CGSize {
        let longest = max(width, height)
        guard longest > maxSide, longest > 0 else { return self }
        let scale = maxSide / longest
        return CGSize(width: (width * scale).rounded(), height: (height * scale).rounded())
    }
}
