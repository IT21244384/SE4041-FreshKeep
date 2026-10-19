import Foundation
import Observation

/// Dependency container injected into the SwiftUI environment.
@Observable
final class AppServices {
    let classifier: FoodClassifying
    let labelReader: LabelReading
    let notifications: NotificationScheduling

    init(classifier: FoodClassifying, labelReader: LabelReading, notifications: NotificationScheduling) {
        self.classifier = classifier
        self.labelReader = labelReader
        self.notifications = notifications
    }

    /// Real services normally; deterministic fakes when UI tests ask for them,
    /// because the simulator has no camera and Vision results vary by machine.
    static func makeForLaunch(arguments: [String] = ProcessInfo.processInfo.arguments) -> AppServices {
        if arguments.contains(LaunchArgument.mockClassifier) {
            return AppServices(classifier: MockFoodClassifier(), labelReader: MockLabelReader(),
                               notifications: NotificationService())
        }
        return AppServices(classifier: VisionFoodClassifier(), labelReader: VisionLabelReader(),
                           notifications: NotificationService())
    }

    static let preview = AppServices(classifier: MockFoodClassifier(), labelReader: MockLabelReader(),
                                     notifications: NotificationService())
}
