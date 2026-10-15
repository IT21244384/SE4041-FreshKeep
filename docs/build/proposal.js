const path = require('path');
const { p, h1, h2, h3, bullet, numbered, table, image, cover, toc, build, pageBreak } = require('./lib');

const children = [
  ...cover({ title: 'FreshKeep', subtitle: 'Eat it before it’s too late — an on-device AI food freshness tracker', docType: 'Project Proposal' }),
  ...toc(),

  h1('1. Introduction'),
  p('Every household throws away food that was bought with good intentions: the bunch of bananas that went brown, the half-used milk carton found behind the yoghurt, the leftover curry that was forgotten. The UNEP Food Waste Index Report 2024 estimates that households waste on average around 79 kg of food per person every year, and that household waste is the largest share of all food waste. Most of it is not caused by carelessness but by **forgetting** — people simply do not remember what they have and when it expires.'),
  p('**FreshKeep** is an iOS app that makes the contents of the kitchen visible. The user points the camera at their groceries and the app recognises the food on the device using Apple’s Vision framework (Core ML), estimates how long it will keep in the fridge, freezer, pantry or on the counter, and can read the “best before” date straight from the packaging. FreshKeep then reminds the user before food expires, suggests recipes that use up what is about to go off, and shows how much food and money they have rescued.'),

  h1('2. Problem Statement'),
  p('Keeping track of food at home is tedious. Existing pantry apps expect the user to type every item and its expiry date, so most people give up after a few days. At the same time, a lot of food has no printed date at all (fresh fruit, vegetables, bakery items, leftovers), and shelf life depends heavily on how it is stored — a banana lasts about five days on the counter but months in the freezer.'),
  bullet('Users do not know what is in their fridge or when it will spoil.'),
  bullet('Manual data entry is slow, so tracking habits do not last.'),
  bullet('Fresh produce has no expiry date to copy; people guess.'),
  bullet('There is no feedback loop — users never see how much they waste or save.'),

  h1('3. Purpose and Objectives'),
  p('The purpose of FreshKeep is to reduce household food waste by making food tracking effortless and by nudging users at the right moment. The objectives are:'),
  numbered('Let users add food in seconds by taking a photo, using on-device machine learning for recognition (no typing, no account, no internet).'),
  numbered('Estimate expiry dates automatically from a built-in shelf-life knowledge base that depends on the storage location.'),
  numbered('Read printed best-before dates from packaging using on-device text recognition, including the difference between MFD and EXP dates.'),
  numbered('Notify users before food expires and suggest recipes that use those items.'),
  numbered('Motivate users with an Insights dashboard (rescue rate, money saved in LKR, CO₂e avoided, streaks).'),
  numbered('Deliver a polished, accessible iOS experience (Dark Mode, Dynamic Type, VoiceOver, iPad layouts).'),

  h1('4. Target Audience'),
  p('FreshKeep is aimed at people who shop for themselves or a family and regularly find spoiled food. Three personas guided the design:'),
  table(['Persona', 'Profile', 'Needs → how FreshKeep helps'], [
    ['Nimali, 34 — working parent', 'Does a weekly supermarket shop for a family of four in Colombo. Busy weekdays.', 'Needs to know what to cook first → “Needs attention” carousel and recipe suggestions.'],
    ['Kasun, 23 — university student', 'Lives in a boarding place with a shared fridge, tight budget.', 'Wants to stop losing money → money-saved stats and reminders the day before expiry.'],
    ['Priya, 61 — retired', 'Shops at the market several times a week; prefers large text.', 'Needs a simple, readable app → Dynamic Type support, big buttons, camera instead of typing.'],
  ], [1.1, 1.6, 2.2]),
  p('**Justification:** smartphone users who buy groceries are a large group, and the problem is universal. Students and young professionals are price-sensitive and respond to money-saved feedback; families benefit from shared awareness of what must be eaten first; older users benefit from capture by photo instead of typing. Prices are shown in LKR and dates are read day-first to match local packaging.'),

  h1('5. Proposed Solution'),
  h2('5.1 Key features'),
  table(['Feature', 'Description'], [
    ['Scan food (AI)', 'Photo → Vision image classification on device → ranked list of foods with confidence. One tap creates a pre-filled item.'],
    ['Scan date label (AI)', 'Photo of packaging → Vision text recognition → expiry date parser that understands formats like 12/11/26, 12 NOV 2026 and MFD vs EXP.'],
    ['Smart shelf-life estimates', 'Catalog of 48 common foods (USDA FoodKeeper guidance) with storage-specific shelf life and storage tips.'],
    ['Pantry dashboard', 'Items grouped by urgency (Expired, Use today, Use soon, Fresh), search, storage filters, swipe and long-press actions.'],
    ['Freshness ring', 'Custom animated component that empties as an item approaches expiry.'],
    ['Freeze it', 'One-tap move to the freezer that recalculates the expiry date.'],
    ['Reminders', 'Local notifications N days before expiry and on the day itself.'],
    ['Use it up', 'Recipes ranked by how many soon-to-expire items they rescue.'],
    ['Insights', 'Rescue rate, money saved, CO₂e avoided, zero-waste streak, weekly chart and waste by category (Swift Charts).'],
  ], [1.2, 3.3]),
  h2('5.2 Mapping to assignment requirements'),
  table(['Requirement', 'How FreshKeep meets it'], [
    ['Real-world problem & audience', 'Household food waste; personas in Section 4.'],
    ['Advanced UI elements', 'Custom animations (ring, scan line, confetti with keyframes, phase animator), gestures (swipe, long-press preview, pinch-to-zoom), adaptive layouts (TabView ↔ NavigationSplitView, ViewThatFits, landscape).'],
    ['SwiftUI components & customisation', 'Custom FreshnessRing view, `.freshCard()` view modifier, custom button styles, viewfinder Shape, filter chips, brand theme.'],
    ['Navigation & architecture', 'NavigationStack with typed destinations per tab, sheets for create/edit, MVVM with services and a shared Swift package.'],
    ['Data persistence', 'SwiftData (Core Data based) with external storage for photos; settings via @AppStorage.'],
    ['Emerging technology', 'Apple Vision + Core ML on-device image classification and text recognition (OCR).'],
    ['Visual design & accessibility', 'Brand palette, custom app icon, Dark Mode colour assets, Dynamic Type, VoiceOver labels, reduced motion.'],
    ['Testing & performance', 'Unit tests (core + app), UI tests, UAT; image downsampling, thumbnail cache, background Vision work.'],
    ['Documentation', 'Proposal, Figma UI documentation, user guide, technical documentation, final report, AI-usage log.'],
  ], [1.4, 3.1]),

  h1('6. Emerging Technology: On-device Machine Learning'),
  p('FreshKeep integrates Apple’s **Vision** framework, which runs **Core ML** models on the iPhone’s Neural Engine:'),
  bullet('`VNClassifyImageRequest` — Apple’s built-in image classifier (1,000+ labels). FreshKeep filters the labels to foods, merges synonyms (e.g. “granny_smith” → Apple) and maps them to its shelf-life catalog.'),
  bullet('`VNRecognizeTextRequest` — accurate text recognition for packaging. The recognised text goes to a custom date parser that prefers the date following an expiry keyword over the manufacture date.'),
  p('Running on the device was a deliberate choice: photos of a person’s kitchen never leave the phone, the app works offline, results are fast and there are no server costs. The integration is central to the product — it removes the data-entry burden that makes other pantry apps fail.'),

  h1('7. Existing Similar Applications'),
  table(['App', 'What it does', 'Gap FreshKeep addresses'], [
    ['NoWaste', 'Manual food inventory with expiry dates and lists.', 'Every item is typed by hand; no recognition of fresh produce.'],
    ['Fridgely', 'Tracks items and expiry dates, barcode scanning.', 'Barcodes do not exist on loose fruit/veg or leftovers; dates are entered manually.'],
    ['KitchenPal', 'Pantry inventory, barcode scanning, shopping lists.', 'Focus on inventory and shopping rather than on rescuing food before it expires.'],
    ['Too Good To Go', 'Marketplace for surplus food from shops and restaurants.', 'Tackles retail waste, not food already in the user’s home.'],
  ], [1, 2, 2]),
  p('FreshKeep’s differentiators are camera-based recognition of unpackaged food, automatic storage-aware expiry estimates, reading dates from labels, and the rescue-focused feedback loop (urgency grouping, recipes and impact stats).'),

  h1('8. Technical Approach'),
  ...image('architecture.png', 6.3, 'Figure 1 — Planned architecture'),
  table(['Layer', 'Technology'], [
    ['Language / UI', 'Swift 5.10+, SwiftUI (iOS 17+), Observation (@Observable)'],
    ['Architecture', 'MVVM, dependency container (AppServices), protocol-based services for testability'],
    ['Persistence', 'SwiftData @Model with external storage for photos; UserDefaults/@AppStorage for settings'],
    ['Machine learning', 'Vision (VNClassifyImageRequest, VNRecognizeTextRequest) — Core ML on device'],
    ['Other frameworks', 'UserNotifications, Swift Charts, PhotosUI, ImageIO, RealityKit (visionOS)'],
    ['Shared logic', 'FreshKeepCore Swift package (catalog, matcher, date parser, freshness, insights, recipes)'],
    ['Tooling', 'Xcode, XcodeGen, GitHub + GitHub Actions (macOS runners), Figma'],
  ], [1.2, 3.3]),
  p('**Development environment note:** the developer uses a Windows laptop. Platform-independent logic is developed and unit-tested locally with the Swift toolchain for Windows, while the full Xcode project is built and tested on GitHub Actions macOS runners on every push (including UI tests in the iOS Simulator, screenshots and a screen recording). A Mac is used for the final device demonstration.'),

  h1('9. UI/UX Design Approach'),
  p('The interface is designed in Figma before implementation (see the separate UI Documentation). Design principles: urgency first, one-tap capture, celebrate rescues, accessible by default and a native iOS feel. The palette uses a leaf green brand colour and a four-step freshness scale (green, amber, orange, red), with all colours defined for both light and dark appearance.'),
  ...image('user-flow.png', 6.3, 'Figure 2 — Planned navigation flow'),

  h1('10. Part B — visionOS Concept (summary)'),
  p('**FreshKeep Spatial** brings the pantry into the room. A volumetric window shows a 3D “virtual fridge” with shelves for each storage location; each item is a token coloured by freshness. The user looks and pinches to inspect an item, or picks it up and drops it into a cooking pot to mark it as eaten and get a recipe idea. An immersive “expiry timeline” arranges food on an arc around the user — the closer an item floats, the sooner it expires. The concept, competitor analysis and business model are presented in the separate pitch deck.'),

  h1('11. Testing Plan'),
  table(['Level', 'What is tested', 'Tool'], [
    ['Unit — core', 'Date parser formats & edge cases, food matcher, shelf-life lookups, freshness levels, insights maths, recipe ranking, reminder timing', 'XCTest (`swift test`)'],
    ['Unit — app', 'SwiftData CRUD & queries, freeze logic, item draft validation, scan view model states, image downsampling', 'XCTest'],
    ['UI', 'Onboarding, add item, validation, scan → add, label scan, mark eaten, insights/settings navigation, dark mode + large text', 'XCUITest'],
    ['Performance', 'App launch time, fetch of 500 items, catalog lookups, memory of image pipeline', 'XCTest metrics, Instruments'],
    ['UAT', 'Five users complete set tasks (scan an item, find what expires first, mark eaten) and rate ease of use', 'Task script + SUS-style questionnaire'],
  ], [0.9, 2.6, 1.2]),

  h1('12. Project Plan'),
  table(['Week', 'Dates (2026)', 'Work'], [
    ['1', '12 – 18 Oct', 'Proposal, research, Figma design system and screens, core package + tests'],
    ['2', '19 – 25 Oct', 'iOS app: pantry, detail, add/edit, persistence, notifications; CI pipeline'],
    ['3', '26 Oct – 1 Nov', 'Vision scanning and OCR, insights & charts, accessibility, unit/UI tests'],
    ['4', '2 – 8 Nov', 'visionOS prototype, performance tuning, UAT with users'],
    ['5', '9 – 15 Nov', 'Final report, user guide, technical documentation, pitch deck, demo rehearsal'],
  ], [0.6, 1.2, 3.2]),

  h1('13. Risks and Mitigation'),
  table(['Risk', 'Impact', 'Mitigation'], [
    ['No Mac available for development', 'High', 'Shared logic tested on Windows; CI on macOS runners builds/tests every push; borrow a Mac for the demo.'],
    ['Classifier misidentifies food', 'Medium', 'Show top matches with confidence; always allow manual correction; category fallback.'],
    ['OCR misreads dates', 'Medium', 'Robust parser with keyword logic; show recognised text; user confirms date.'],
    ['Shelf-life estimates are approximate', 'Low', 'Clearly labelled as estimates; editable; storage tips encourage checking food.'],
    ['Scope creep', 'Medium', 'MVP features first; visionOS kept as a focused prototype.'],
  ], [1.6, 0.6, 2.6]),

  h1('14. References'),
  numbered('United Nations Environment Programme (2024). Food Waste Index Report 2024. Nairobi: UNEP.', 'numbers2'),
  numbered('Apple Inc. Vision framework documentation — Classifying images and recognising text. developer.apple.com/documentation/vision', 'numbers2'),
  numbered('Apple Inc. SwiftData documentation. developer.apple.com/documentation/swiftdata', 'numbers2'),
  numbered('Apple Inc. Human Interface Guidelines (iOS and visionOS). developer.apple.com/design/human-interface-guidelines', 'numbers2'),
  numbered('USDA Food Safety and Inspection Service. FoodKeeper App data (shelf-life guidance). foodsafety.gov', 'numbers2'),
];

build(path.join(__dirname, '..', 'FreshKeep_Proposal_IT21244384.docx'), children, 'Project Proposal');
