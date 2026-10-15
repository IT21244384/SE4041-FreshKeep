import UIKit
import Vision
import FreshKeepCore

/// Recognises food in a photo.
protocol FoodClassifying {
    func classify(_ image: UIImage) async throws -> [FoodMatch]
}

enum ClassifierError: LocalizedError {
    case invalidImage

    var errorDescription: String? {
        switch self {
        case .invalidImage: "That photo couldn't be read. Try another one."
        }
    }
}

/// On-device food recognition using Apple's Vision framework.
///
/// `VNClassifyImageRequest` runs Apple's built-in Core ML image classifier (over 1,000
/// labels, accelerated by the Neural Engine). The raw labels are passed to
/// `FoodMatcher` from FreshKeepCore, which keeps only foods and maps them to the
/// shelf-life catalog. Nothing is uploaded, so it works offline and keeps photos private.
struct VisionFoodClassifier: FoodClassifying {
    var matcher = FoodMatcher()

    func classify(_ image: UIImage) async throws -> [FoodMatch] {
        guard let cgImage = image.cgImage else { throw ClassifierError.invalidImage }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        let matcher = matcher

        // Vision is synchronous and CPU/ANE heavy, so run it off the main actor.
        return try await Task.detached(priority: .userInitiated) {
            let request = VNClassifyImageRequest()
            #if targetEnvironment(simulator)
            // The simulator has no Neural Engine.
            request.usesCPUOnly = true
            #endif
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation)
            try handler.perform([request])
            let observations = (request.results ?? [])
                .filter { $0.hasMinimumPrecision(0.1, forRecall: 0.8) || $0.confidence > 0.2 }
                .map { ClassifierObservation(identifier: $0.identifier, confidence: Double($0.confidence)) }
            return matcher.matches(from: observations)
        }.value
    }
}

/// Fixed results for previews and UI tests.
struct MockFoodClassifier: FoodClassifying {
    var observations: [ClassifierObservation] = [
        .init(identifier: "banana", confidence: 0.91),
        .init(identifier: "mango", confidence: 0.34),
        .init(identifier: "fruit", confidence: 0.95)
    ]
    var delay: Duration = .milliseconds(900)

    func classify(_ image: UIImage) async throws -> [FoodMatch] {
        try await Task.sleep(for: delay)
        return FoodMatcher().matches(from: observations)
    }
}

extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
