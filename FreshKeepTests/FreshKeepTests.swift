import XCTest
import SwiftData
import UIKit
import FreshKeepCore
@testable import FreshKeep

/// Persistence tests run against an in-memory SwiftData store.
@MainActor
final class PantryItemTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUpWithError() throws {
        container = try ModelContainer(for: PantryItem.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        context = container.mainContext
    }

    override func tearDown() {
        container = nil
        context = nil
    }

    private func makeItem(_ name: String = "Milk", daysLeft: Int = 3, status: ItemStatus = .active) -> PantryItem {
        let expiry = Calendar.current.date(byAdding: .day, value: daysLeft, to: Calendar.current.startOfDay(for: .now))!
        return PantryItem(name: name, catalogID: ShelfLifeCatalog.shared.profile(named: name)?.id, category: .dairy,
                          storage: .fridge, quantity: 2, addedAt: .now.addingTimeInterval(-86_400), expiresAt: expiry,
                          price: 400, status: status)
    }

    func testInsertAndFetchActiveSortedByExpiry() throws {
        context.insert(makeItem("Milk", daysLeft: 5))
        context.insert(makeItem("Yogurt", daysLeft: 1))
        context.insert(makeItem("Cheese", daysLeft: 3, status: .eaten))
        try context.save()

        let descriptor = FetchDescriptor<PantryItem>(predicate: #Predicate { $0.statusRaw == "active" },
                                                     sortBy: [SortDescriptor(\.expiresAt)])
        let active = try context.fetch(descriptor)
        XCTAssertEqual(active.map(\.name), ["Yogurt", "Milk"])
    }

    func testResolveSetsStatusAndTimestamp() {
        let item = makeItem()
        item.resolve(as: .eaten)
        XCTAssertEqual(item.status, .eaten)
        XCTAssertNotNil(item.resolvedAt)
        item.resolve(as: .active)
        XCTAssertNil(item.resolvedAt)
    }

    func testFreezeExtendsExpiryAndMovesToFreezer() {
        let item = makeItem("Chicken", daysLeft: 1)
        item.catalogID = "chicken"
        let before = item.expiresAt
        XCTAssertTrue(item.freeze())
        XCTAssertEqual(item.storage, .freezer)
        XCTAssertGreaterThan(item.expiresAt, before)
        XCTAssertFalse(item.freeze(), "Freezing twice should do nothing")
    }

    func testRecordUsesTotalValue() {
        let record = makeItem().record
        XCTAssertEqual(record.price, 800) // 2 × 400
        XCTAssertEqual(record.category, .dairy)
    }

    func testProfileFallsBackToName() {
        let item = PantryItem(name: "Bananas", category: .fruit, storage: .counter, expiresAt: .now)
        XCTAssertEqual(item.profile?.id, "banana")
        XCTAssertEqual(item.emoji, "🍌")
    }

    func testSampleDataSeedsActiveAndHistory() throws {
        SampleData.insert(into: context)
        let all = try context.fetch(FetchDescriptor<PantryItem>())
        XCTAssertGreaterThan(all.filter { $0.status == .active }.count, 5)
        XCTAssertGreaterThan(all.filter { $0.status != .active }.count, 10)
    }

    func testFetchPerformanceWithManyItems() throws {
        for index in 0..<500 { context.insert(makeItem("Item \(index)", daysLeft: index % 30)) }
        try context.save()
        let descriptor = FetchDescriptor<PantryItem>(predicate: #Predicate { $0.statusRaw == "active" },
                                                     sortBy: [SortDescriptor(\.expiresAt)])
        measure {
            _ = try? context.fetch(descriptor)
        }
    }
}

final class ItemDraftTests: XCTestCase {
    private let banana = ShelfLifeCatalog.shared.profile(named: "banana")!

    func testDraftFromProfileEstimatesExpiry() {
        let draft = ItemDraft(profile: banana)
        XCTAssertEqual(draft.storage, .counter)
        XCTAssertEqual(draft.price, banana.typicalPrice)
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: .now), to: draft.expiresAt).day
        XCTAssertEqual(days, 5)
    }

    func testChangingStorageReestimates() {
        var draft = ItemDraft(profile: banana)
        draft.storage = .freezer
        draft.reestimateExpiry()
        XCTAssertEqual(draft.estimatedShelfLifeDays, 90)
    }

    func testManualDateIsNotOverwritten() {
        var draft = ItemDraft(profile: banana)
        let manual = Date.now.addingTimeInterval(86_400 * 40)
        draft.expiresAt = manual
        draft.expirySource = .manual
        draft.storage = .fridge
        draft.reestimateExpiry()
        XCTAssertEqual(draft.expiresAt, manual)
    }

    func testValidation() {
        var draft = ItemDraft()
        XCTAssertFalse(draft.isValid)
        draft.name = "   "
        XCTAssertFalse(draft.isValid)
        draft.name = "Leftover curry"
        XCTAssertTrue(draft.isValid)
    }

    func testApplyProfileFromSuggestion() {
        var draft = ItemDraft()
        draft.name = "car"
        draft.apply(ShelfLifeCatalog.shared.profile(named: "carrot")!)
        XCTAssertEqual(draft.name, "Carrot")
        XCTAssertEqual(draft.category, .vegetable)
        XCTAssertEqual(draft.storage, .fridge)
    }

    func testMakeItemTrimsName() {
        var draft = ItemDraft(profile: banana)
        draft.name = "  Banana  "
        XCTAssertEqual(draft.makeItem().name, "Banana")
    }
}

@MainActor
final class ScanViewModelTests: XCTestCase {
    private func image() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 3000, height: 2000)).image { ctx in
            UIColor.yellow.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 3000, height: 2000))
        }
    }

    private func waitUntilDone(_ model: ScanViewModel) async {
        for _ in 0..<100 where model.isAnalyzing {
            try? await Task.sleep(for: .milliseconds(20))
        }
    }

    func testFoodScanProducesMatchesAndDownsamples() async {
        let model = ScanViewModel(classifier: MockFoodClassifier(delay: .zero), labelReader: MockLabelReader())
        model.analyze(image())
        XCTAssertEqual(model.phase, .analyzing)
        await waitUntilDone(model)
        guard case .foods(let matches) = model.phase else { return XCTFail("Expected matches, got \(model.phase)") }
        XCTAssertEqual(matches.first?.id, "banana")
        // Working image is capped at 1280 px for memory and speed.
        XCTAssertLessThanOrEqual(max(model.image!.size.width, model.image!.size.height), 1280)
        XCTAssertEqual(model.draft(for: matches[0]).name, "Banana")
    }

    func testNoFoodWhenClassifierFindsNothing() async {
        let model = ScanViewModel(classifier: MockFoodClassifier(observations: [.init(identifier: "chair", confidence: 0.9)], delay: .zero),
                                  labelReader: MockLabelReader())
        model.analyze(image())
        await waitUntilDone(model)
        XCTAssertEqual(model.phase, .noFood)
    }

    func testLabelModeReadsDate() async {
        let model = ScanViewModel(classifier: MockFoodClassifier(delay: .zero), labelReader: MockLabelReader())
        model.setMode(.label)
        model.analyze(image())
        await waitUntilDone(model)
        guard case .label(let scan) = model.phase else { return XCTFail("Expected label result") }
        XCTAssertNotNil(scan.expiryDate)
        let draft = model.draft(for: scan)
        XCTAssertEqual(draft.expirySource, .label)
        XCTAssertEqual(draft.expiresAt, scan.expiryDate)
    }

    func testSwitchingModeResets() {
        let model = ScanViewModel(classifier: MockFoodClassifier(), labelReader: MockLabelReader())
        model.analyze(image())
        model.setMode(.label)
        XCTAssertEqual(model.phase, .idle)
        XCTAssertNil(model.image)
    }
}

final class ImagePipelineTests: XCTestCase {
    func testSizeFittingNeverUpscales() {
        XCTAssertEqual(CGSize(width: 4000, height: 3000).fitting(maxSide: 1000), CGSize(width: 1000, height: 750))
        XCTAssertEqual(CGSize(width: 300, height: 200).fitting(maxSide: 1000), CGSize(width: 300, height: 200))
    }

    func testStorageDataIsDownsampled() throws {
        let big = UIGraphicsImageRenderer(size: CGSize(width: 4000, height: 3000), format: {
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            return format
        }()).image { ctx in
            UIColor.green.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 4000, height: 3000))
        }
        let data = try XCTUnwrap(ImagePipeline.storageData(from: big))
        let stored = try XCTUnwrap(UIImage(data: data))
        XCTAssertLessThanOrEqual(max(stored.size.width * stored.scale, stored.size.height * stored.scale), 1024)
    }
}
