import UIKit
import Vision
import FreshKeepCore

/// Text and expiry date found on a packaging label.
struct LabelScan: Equatable {
    let recognizedText: String
    let expiryDate: Date?
}

/// Reads best-before dates from photos of packaging.
protocol LabelReading {
    func read(_ image: UIImage) async throws -> LabelScan
}

/// Uses Vision's on-device text recognition (OCR) and FreshKeepCore's
/// `ExpiryDateParser` to turn a photo of a label into a date.
struct VisionLabelReader: LabelReading {
    var parser = ExpiryDateParser(calendar: .current)

    func read(_ image: UIImage) async throws -> LabelScan {
        guard let cgImage = image.cgImage else { throw ClassifierError.invalidImage }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        let parser = parser

        return try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            // Dates like "12.11.26" get "corrected" into words by the language model, so turn it off.
            request.usesLanguageCorrection = false
            request.minimumTextHeight = 0.02
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation)
            try handler.perform([request])
            let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
            let text = lines.joined(separator: "\n")
            return LabelScan(recognizedText: text, expiryDate: parser.parse(text))
        }.value
    }
}

/// Deterministic label reader for previews and UI tests.
struct MockLabelReader: LabelReading {
    var text = "FRESH MILK 1L\nMFD 10/10/2026\nUSE BY 21 OCT 2026"

    func read(_ image: UIImage) async throws -> LabelScan {
        try await Task.sleep(for: .milliseconds(600))
        return LabelScan(recognizedText: text, expiryDate: ExpiryDateParser(calendar: .current).parse(text))
    }
}
