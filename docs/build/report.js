const fs = require('fs');
const path = require('path');
const { p, h1, h2, h3, bullet, numbered, table, image, imageRow, cover, toc, build, pageBreak, markdown, IMG, Paragraph, run, AlignmentType } = require('./lib');

const R = JSON.parse(fs.readFileSync(path.join(__dirname, 'results.json'), 'utf8'));
const has = (f) => fs.existsSync(path.join(IMG, f));
const code = (lines) => new Paragraph({ shading: { fill: 'F2F5F1', type: 'clear', color: 'auto' }, spacing: { after: 160 },
  children: lines.map((c, k) => run(c || ' ', { font: 'Consolas', size: 17, break: k ? 1 : 0 })) });
const shots = (files, caps, w = 1.95) => {
  const f = files.filter(has);
  return f.length ? [imageRow(f, w, files.map((x, i) => (has(x) ? caps[i] : null)).filter((x) => x !== null))] : [];
};

const children = [
  ...cover({ title: 'FreshKeep', subtitle: 'Eat it before it’s too late — an on-device AI food freshness tracker', docType: 'Final Report' }),
  ...toc(),

  h1('1. Executive Summary'),
  p('FreshKeep is a SwiftUI iOS app that reduces household food waste. Users photograph their groceries; Apple’s Vision framework (Core ML) recognises the food on the device and FreshKeep estimates how long it will last based on where it is stored. It can also read printed best-before dates, sends reminders before food expires, suggests recipes that use up what is about to spoil, and reports the food, money and emissions the user has saved. A visionOS prototype, FreshKeep Spatial, extends the idea to a 3D virtual fridge and an immersive expiry timeline (Part B).'),
  table(['Outcome', 'Result'], [
    ['Screens', '9 iPhone screens + iPad sidebar layout, Dark Mode and Dynamic Type variants'],
    ['Emerging technology', 'Vision `VNClassifyImageRequest` (Core ML) + `VNRecognizeTextRequest` OCR, fully on device'],
    ['Persistence', 'SwiftData model with external photo storage; settings in @AppStorage'],
    ['Automated tests', `${R.coreTests} core unit tests, ${R.appUnitTests} app unit tests, ${R.uiTests} UI tests — ${R.passSummary}`],
    ['Code coverage (app target)', R.coverage],
    ['visionOS prototype', 'Builds and launches in the Apple Vision Pro simulator in CI'],
    ['Repository', 'github.com/IT21244384/SE4041-FreshKeep (feature branches, pull requests, CI on every push)'],
  ], [1.4, 3.1]),

  h1('2. Introduction'),
  h2('2.1 Problem'),
  p('Households are the largest single source of food waste; UNEP’s Food Waste Index Report 2024 estimates about 79 kg per person per year. Most of it is wasted because people forget what they have and when it expires. Existing pantry apps depend on manual entry, which users abandon, and loose produce has no printed date to copy.'),
  h2('2.2 Purpose and target audience'),
  p('FreshKeep’s purpose is to make tracking effortless and to nudge the user at the right time. It targets people who shop for themselves or a family — busy parents, students on a budget and older users who prefer large text — as described by the three personas in the proposal. Local context was considered: prices are in LKR, dates on packaging are read day-first, and the catalog includes local staples (coconut, brinjal, green chilli, cooked rice, curry).'),

  h1('3. Requirements and How They Were Met'),
  table(['Assignment requirement', 'Implementation', 'Where'], [
    ['Purpose & target audience', 'Food-waste problem, personas, local adaptation', 'Proposal §2–4'],
    ['Advanced UI elements', 'Keyframe confetti, phase-animated onboarding, animated ring and scan line, 3D scroll transition, swipe / long-press / pinch gestures, adaptive layouts', '`Views/`, `DesignSystem/Effects.swift`'],
    ['SwiftUI components & customisation', 'FreshnessRing, `.freshCard()` modifier, button styles, ViewfinderShape, FilterChip, ShakeEffect; brand theme', '`DesignSystem/`'],
    ['≥3 navigable screens', 'Pantry, Item detail, Add/Edit, Scan, Insights, Recipe, Settings, Onboarding', '`Views/`'],
    ['Navigation & architecture', 'NavigationStack per tab with typed destinations, NavigationSplitView on iPad, sheets; MVVM + services + shared package', '`RootView.swift`'],
    ['Data persistence', 'SwiftData @Model, predicates and sort descriptors, external storage', '`Shared/PantryItem.swift`'],
    ['Emerging technology', 'Vision / Core ML food recognition and OCR', '`Services/FoodClassifier.swift`, `LabelReader.swift`'],
    ['Visual design & branding', 'Custom icon, colour tokens, Figma design system', 'Figma file, `Resources/Assets.xcassets`'],
    ['Accessibility', 'Dark Mode assets, Dynamic Type, VoiceOver labels, Reduce Motion', 'UI Documentation §6–7'],
    ['Testing & optimisation', 'Unit, UI and performance tests, UAT plan; ImageIO downsampling, caching, background Vision', '§7–8'],
    ['Documentation', 'User guide, technical documentation, this report, UI documentation, AI log', 'Appendices, `docs/`'],
    ['Deployment & presentation', 'CI builds, simulator recording, README build steps, demo script', '§10, README'],
  ], [1.4, 2.3, 1.3]),

  h1('4. Design Decisions'),
  h2('4.1 Architecture'),
  ...image('architecture.png', 6.2, 'Figure 1 — FreshKeep architecture'),
  p('**MVVM with protocol-based services.** Views stay declarative; `ScanViewModel` owns the asynchronous Vision pipeline; services hide Apple frameworks behind protocols so tests and previews can inject mocks. A tiny dependency container (`AppServices`) is passed through the SwiftUI environment.'),
  p('**A shared Swift package (FreshKeepCore).** All business logic that does not need UIKit — the food catalog, label matcher, date parser, freshness maths, insights, recipe ranking and reminder timing — lives in a package used by both the iOS and visionOS apps. This made the logic fast to test (it runs with `swift test` on any machine, including my Windows laptop) and kept views thin.'),
  p('**SwiftData over Core Data or Realm.** SwiftData gives Core Data’s proven SQLite store with a Swift-native model, `@Query` for reactive lists and `#Predicate` filters, with no third-party dependency. Enums are stored as raw strings because predicates cannot use computed properties. Eaten and wasted items are kept rather than deleted so the Insights screen has history.'),
  p('**On-device ML instead of a cloud API.** Vision’s built-in classifier runs on the Neural Engine, works offline, costs nothing per request and keeps photos of the user’s kitchen private. The trade-off is a generic label set, which FreshKeep compensates for with the synonym-aware `FoodMatcher`, a category fallback and always-editable results.'),
  p('**XcodeGen.** The Xcode project is generated from `project.yml`. This avoids merge conflicts in `.pbxproj` files and, crucially, let the project be created and built from a clean checkout on CI without ever opening Xcode.'),
  h2('4.2 UX decisions'),
  bullet('**Urgency first** — the home screen is sorted and grouped by days left, with a “Needs attention” carousel, because the core job is deciding what to eat first.'),
  bullet('**Estimates over empty fields** — every item gets a sensible expiry immediately; the user only corrects it if needed. The form explains where the date came from.'),
  bullet('**Never colour alone** — every freshness colour is paired with text for colour-blind users and VoiceOver.'),
  bullet('**Positive reinforcement** — rescuing food triggers confetti, a haptic and a toast; Insights shows money saved rather than only waste.'),
  bullet('**Permission in context** — notification permission is requested at the end of onboarding, after explaining why.'),

  h1('5. User Interface'),
  p('The UI was designed in Figma (design system, components and screens) and implemented in SwiftUI; the separate UI Documentation pairs each Figma frame with the implemented screen. The screenshots below were captured automatically by the UI tests on an iPhone 17 Pro simulator in CI.'),
  ...shots(['app/03-pantry.png', 'app/04-item-detail.png', 'app/06-scan-results.png'], ['Pantry', 'Item detail', 'Scan results']),
  ...shots(['app/05-add-item.png', 'app/08-insights.png', 'app/11-dark-large-text.png'], ['Add item', 'Insights', 'Dark Mode + AX text']),

  h1('6. Implementation'),
  h2('6.1 Food recognition pipeline'),
  p('Photos are downsampled to at most 1280 px before analysis. Vision runs in a detached task so the interface stays responsive; a new photo cancels the previous analysis.'),
  code([
    'let request = VNClassifyImageRequest()',
    '#if targetEnvironment(simulator)',
    'request.usesCPUOnly = true          // no Neural Engine in the Simulator',
    '#endif',
    'try VNImageRequestHandler(cgImage: cgImage, orientation: orientation).perform([request])',
    'let observations = (request.results ?? [])',
    '    .filter { $0.hasMinimumPrecision(0.1, forRecall: 0.8) || $0.confidence > 0.2 }',
    '    .map { ClassifierObservation(identifier: $0.identifier, confidence: Double($0.confidence)) }',
    'return FoodMatcher().matches(from: observations)   // foods only, synonyms merged',
  ]),
  h2('6.2 Reading best-before dates'),
  p('`VNRecognizeTextRequest` (accurate mode, language correction off) returns text lines that `ExpiryDateParser` scans with ordered regular expressions: ISO dates, day–month-name–year, month-name–day–year, numeric day-first dates (swapping when the first number cannot be a month) and month/year dates, which mean the end of that month. When a label shows both a manufacture and an expiry date, the parser picks the first date that follows an expiry keyword (EXP, USE BY, BB…) and is not closer to an MFD keyword. Impossible dates such as 31/02/2026 are rejected — a case that the unit tests caught (see §9).'),
  h2('6.3 Persistence and reminders'),
  p('`PantryItem` is a SwiftData `@Model`. Lists use `@Query(filter: #Predicate { $0.statusRaw == "active" }, sort: \\.expiresAt)` so filtering and sorting happen in SQLite. When an item is saved, `ReminderPlanner` computes a “use soon” reminder N days before expiry and one on the morning of expiry; `NotificationService` schedules them with calendar triggers and cancels them when the item is eaten, wasted or deleted.'),
  h2('6.4 Custom components'),
  code([
    'struct FreshnessRing: View {',
    '    let freshness: Freshness',
    '    @ScaledMetric private var scale: CGFloat = 1        // grows with Dynamic Type',
    '    @State private var animatedFraction: Double = 0',
    '    var body: some View {',
    '        ZStack {',
    '            Circle().stroke(color.opacity(0.18), lineWidth: lineWidth)',
    '            Circle().trim(from: 0, to: animatedFraction)',
    '                .stroke(color.gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))',
    '                .rotationEffect(.degrees(-90))',
    '            // days label …',
    '        }',
    '        .onAppear { withAnimation(.easeOut(duration: 0.9)) { animatedFraction = freshness.remainingFraction } }',
    '        .accessibilityValue("\\(freshness.level.title), \\(freshness.summary)")',
    '    }',
    '}',
  ]),
  h2('6.5 Adaptive layout'),
  p('`RootView` checks the horizontal size class: compact width shows a `TabView`; regular width shows a `NavigationSplitView` sidebar with the same sections. The item detail uses `ViewThatFits` to place cards side by side when there is room, and the scan screen switches between vertical and horizontal stacks with `AnyLayout` in landscape.'),

  h1('7. Testing'),
  h2('7.1 Strategy'),
  table(['Level', 'Tool', 'Scope'], [
    ['Unit — core', 'XCTest via `swift test` (Windows + macOS CI)', 'Parser, matcher, catalog, freshness, insights, recipes, reminders'],
    ['Unit — app', 'XCTest (iOS Simulator)', 'SwiftData queries, resolve/freeze, drafts, scan view model with mocks, image pipeline'],
    ['UI', 'XCUITest', 'End-to-end flows with an in-memory store and mock classifier for repeatability'],
    ['Performance', 'XCTest `measure`, launch metric', 'Catalog lookups, 500-item fetch, app launch'],
    ['User acceptance', 'Task-based sessions', 'Five participants, scripted tasks, satisfaction questions'],
  ], [1.1, 1.6, 2.3]),
  h2('7.2 Automated test results'),
  table(['Suite', 'Tests', 'Passed', 'Notes'], R.suites, [1.6, 0.6, 0.7, 2.1]),
  p(`Code coverage for the FreshKeep app target (unit + UI tests): **${R.coverage}**. All automated tests run on every push in GitHub Actions on ${R.device} with ${R.xcode}.`),
  h3('Selected unit test cases'),
  table(['Test', 'What it proves'], [
    ['testPrefersExpiryOverManufactureDate', '“MFD 01/10/2026 EXP 01/04/2027” → 1 April 2027'],
    ['testRejectsImpossibleDates', '31/02/2026 is not a date (regression test for a bug found during development)'],
    ['testMonthAndYearOnlyMeansEndOfMonth', '“EXP 02/2028” → 29 February 2028 (leap year)'],
    ['testMergesAliasesAndKeepsHighestConfidence', '“granny_smith” 62% and “apple” 30% → one Apple match at 62%'],
    ['testPrefersRecipesUsingUrgentItems', 'A banana expiring today ranks Banana Smoothie first'],
    ['testFreezeExtendsExpiryAndMovesToFreezer', 'Freezing chicken extends expiry and cannot be applied twice'],
    ['testFoodScanProducesMatchesAndDownsamples', 'Scan state machine reaches results; working image ≤ 1280 px'],
  ], [2.2, 2.8]),
  h2('7.3 Performance results'),
  table(['Measurement', 'Result', 'How'], R.performance, [1.8, 1.2, 2]),
  h2('7.4 User acceptance testing'),
  p('UAT is run with five participants who match the personas, using the app on an iPhone. Each participant completes the tasks below without help while thinking aloud; completion, time and errors are recorded, followed by three 1–5 rating questions.'),
  table(['#', 'Task', 'Success criterion'], [
    ['T1', 'Add a banana by taking a photo', 'Item saved with a suggested expiry in < 60 s'],
    ['T2', 'Find which item must be eaten first', 'Opens the correct item from “Needs attention”'],
    ['T3', 'Add milk using the date on the carton', 'Expiry read from the label and saved'],
    ['T4', 'Mark an item as eaten', 'Uses swipe or the detail button'],
    ['T5', 'Find how much money you have saved', 'Opens Insights and reads the value'],
  ], [0.4, 2.4, 2.2]),
  p('Results table (to be completed after the sessions):'),
  table(['Participant', 'T1', 'T2', 'T3', 'T4', 'T5', 'Ease (1–5)', 'Comments'], [
    ['P1', '', '', '', '', '', '', ''], ['P2', '', '', '', '', '', '', ''], ['P3', '', '', '', '', '', '', ''],
    ['P4', '', '', '', '', '', '', ''], ['P5', '', '', '', '', '', '', ''],
  ], [1, 0.5, 0.5, 0.5, 0.5, 0.5, 0.8, 1.6]),

  h1('8. Performance Optimisation'),
  bullet('**Memory:** camera images (~12 MP, ~48 MB decoded) are never decoded at full size; ImageIO thumbnails are created directly from the compressed data. Stored photos are ≤ 1024 px JPEGs (~150 KB). Thumbnails are cached in an `NSCache` limited to 150 entries.'),
  bullet('**Storage:** photos use SwiftData external storage, so list fetches don’t load image blobs.'),
  bullet('**Responsiveness:** Vision runs in a detached task with user-initiated priority; stale analyses are cancelled.'),
  bullet('**Rendering:** lazy stacks/grids, value-type derived data, and animations limited to transforms and opacity.'),
  bullet('**Launch:** no network, no heavy work at launch; sample data is only inserted when requested.'),

  h1('9. Development Challenges'),
  table(['Challenge', 'What happened', 'Resolution'], [
    ['No Mac', 'Xcode only runs on macOS; my laptop runs Windows.', 'Wrote shared logic as a Swift package tested on Windows; generated the project with XcodeGen and built/tested it on GitHub Actions macOS runners on every push (including screen recordings and screenshots).'],
    ['Date parser bug', '“31/02/2026” was rejected, but a looser pattern then read “02/2026” as 28 Feb.', 'Matched text is now claimed even when the date is invalid. Regression test added.'],
    ['Name clash on visionOS', '`Scene` was ambiguous because RealityKit also defines `Scene`.', 'Qualified as `SwiftUI.Scene`.'],
    ['Flaky UI tests', 'System permission alert and list-row lookups differ between OS versions.', 'Handled the alert through SpringBoard and looked up rows by identifier regardless of element type.'],
    ['Simulator has no camera', 'The scan flow could not be exercised in CI.', 'Injected a mock classifier via a launch argument and added a “Try a sample photo” debug button.'],
    ['Figma plan limits', 'The free plan allows 3 pages, 1 variable mode and a limited number of API calls.', 'Light/dark tokens as two variable groups; designs grouped into sections.'],
  ], [1.1, 1.7, 2.2]),

  h1('10. Deployment and Demonstration'),
  p('The app builds from a clean checkout with `xcodegen generate` and Xcode 16 or later; README contains the steps. Every push produces build artifacts: UI-test screenshots, an MP4 recording of the UI tests running in the simulator, a code-coverage report and a visionOS screenshot and recording. For the live demonstration the app is run from Xcode on a Mac on an iPhone (camera scanning) and in the Apple Vision Pro simulator.'),
  p('**Demo script:** onboarding → load sample pantry → swipe an item as eaten (confetti) → scan a banana → read a date from a milk carton → item detail and freeze → Insights and a recipe → Dark Mode and large text → visionOS fridge and timeline.'),

  h1('11. Part B — FreshKeep Spatial (visionOS)'),
  p('FreshKeep Spatial reuses the SwiftData model and FreshKeepCore. It offers a glass main window with an ornament, a volumetric “virtual fridge” built from RealityKit entities generated in code (shelves per storage location, tokens coloured by freshness, a cooking pot) and a mixed immersive “expiry timeline”. Users look and pinch to see an item’s floating card, or pinch and drag it into the pot to mark it eaten and get a recipe idea. The concept, competitor analysis, revenue model and go-to-market plan are in the pitch deck.'),
  ...(has('visionos-main.png') ? image('visionos-main.png', 5.6, 'Figure — FreshKeep Spatial in the Apple Vision Pro simulator') : []),

  h1('12. Use of AI Tools'),
  p('Claude (Anthropic) was used as a coding assistant, as permitted by the brief. It helped scaffold the project structure, CI scripts and asset catalogs, suggested edge cases for tests, and drafted parts of the documentation. I chose the problem, audience and features, reviewed and tested all generated code, and verified facts and shelf-life values. Prompts, outputs and how they were used are recorded in `docs/AI_USAGE_LOG.md` in the repository.'),

  h1('13. Reflection'),
  p('The most valuable lesson was to separate logic from UI early. Putting the catalog, parser and statistics into a package let me test them in seconds without a simulator, and those tests caught a real bug before it reached the app. Designing the component library in Figma first also paid off: each component became one SwiftUI view or modifier, and the screens were quick to assemble.'),
  p('Working without a Mac was the biggest constraint. Building through CI made each compile cycle slower (around ten minutes), which pushed me to write more carefully, rely on the compiler’s strictness and test logic locally. If I repeated the project I would set up the CI pipeline on day one — the automatic screenshots and recordings were also very useful for documentation.'),
  p('If I had more time I would train a Create ML model on local produce (jackfruit, gotukola, rambutan), add barcode lookup for packaged goods, iCloud sync for shared households and home-screen widgets for items that must be used today.'),

  h1('14. Conclusion'),
  p('FreshKeep meets the assignment requirements with a polished, accessible SwiftUI app that integrates on-device machine learning in a way that is central to the product, persists data with SwiftData, follows a clean architecture, and is backed by automated tests and continuous integration. The visionOS prototype shows how the same core can power a spatial experience.'),

  h1('15. References'),
  numbered('United Nations Environment Programme (2024). Food Waste Index Report 2024. Nairobi: UNEP.', 'numbers5'),
  numbered('Apple Inc. Vision framework. developer.apple.com/documentation/vision', 'numbers5'),
  numbered('Apple Inc. SwiftData. developer.apple.com/documentation/swiftdata', 'numbers5'),
  numbered('Apple Inc. Swift Charts. developer.apple.com/documentation/charts', 'numbers5'),
  numbered('Apple Inc. RealityKit and visionOS. developer.apple.com/visionos', 'numbers5'),
  numbered('Apple Inc. Human Interface Guidelines. developer.apple.com/design/human-interface-guidelines', 'numbers5'),
  numbered('USDA FSIS. FoodKeeper data. foodsafety.gov/keep-food-safe/foodkeeper-app', 'numbers5'),
  numbered('XcodeGen. github.com/yonaskolb/XcodeGen', 'numbers5'),

  pageBreak(),
  h1('Appendix A — User Guide'),
  ...markdown(path.join(__dirname, '..', 'USER_GUIDE.md'), { shift: 1 }),
  pageBreak(),
  h1('Appendix B — Technical Documentation'),
  ...markdown(path.join(__dirname, '..', 'TECHNICAL.md'), { shift: 1 }),
];

build(path.join(__dirname, '..', 'FreshKeep_Final_Report_IT21244384.docx'), children, 'Final Report');
