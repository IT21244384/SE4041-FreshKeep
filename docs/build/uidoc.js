const fs = require('fs');
const path = require('path');
const { p, h1, h2, h3, bullet, numbered, table, image, imageRow, cover, toc, build, pageBreak, IMG, Paragraph, run, AlignmentType } = require('./lib');
const { Table, TableRow, TableCell, WidthType, ShadingType, BorderStyle } = require('docx');
const { CONTENT_W } = require('./lib');

const FIGMA_URL = 'https://www.figma.com/design/XzRIMOQaZ2idUztQPhRcZC';
const has = (f) => fs.existsSync(path.join(IMG, f));
const note = (t) => p(`[${t}]`, { run: { italics: true, color: '9AA79F' }, align: AlignmentType.CENTER });

/** Figma design and implemented screen side by side. */
function pair(figmaFile, appFile, caption) {
  const files = []; const caps = [];
  if (has(figmaFile)) { files.push(figmaFile); caps.push('Figma design'); }
  if (has(appFile)) { files.push(appFile); caps.push('Implemented (iOS Simulator)'); }
  if (!files.length) return [note(`Screens to be added: ${figmaFile}, ${appFile}`)];
  return [imageRow(files, 2.3, caps), new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 200 }, children: [run(caption, { italics: true, size: 20, color: '5F6B64' })] })];
}

// Colour swatch table using real cell shading.
const tokens = [
  ['Brand / primary', '2BAE66', '3CC27A', 'Buttons, selected chips, tab tint, “fresh”'],
  ['Brand / deep', '0F6B47', '1F8A5C', 'Gradients, headings in documents'],
  ['Citrus', 'F5A524', 'FFB84D', 'Tips, streak icon, secondary accent'],
  ['Freshness / soon', 'E8A317', 'F7BE45', '“Use soon” (1–2 days left)'],
  ['Freshness / today', 'EF6C2F', 'FF8A50', '“Use today”'],
  ['Freshness / expired', 'D93D3D', 'FF6B6B', '“Expired”'],
  ['Surface / background', 'F4F6F1', '0E1311', 'Screen background'],
  ['Surface / card', 'FFFFFF', '1C2320', 'Cards, rows, tab bar'],
  ['Text / primary', '111814', 'F2F5F1', 'Body and titles'],
  ['Text / secondary', '5F6B64', '9AA79F', 'Captions, metadata'],
];
function swatches() {
  const w = [2400, 1500, 1500, CONTENT_W - 5400];
  const border = { style: BorderStyle.SINGLE, size: 4, color: 'BFC9C2' };
  const borders = { top: border, bottom: border, left: border, right: border };
  const cell = (children, i, fill, header) => new TableCell({ borders, width: { size: w[i], type: WidthType.DXA },
    shading: fill ? { fill, type: ShadingType.CLEAR, color: 'auto' } : undefined, margins: { top: 60, bottom: 60, left: 100, right: 100 },
    children: [new Paragraph({ children: [run(children, { size: 20, bold: header, color: header ? 'FFFFFF' : undefined })] })] });
  const dark = (hex) => parseInt(hex.slice(0, 2), 16) * 0.3 + parseInt(hex.slice(2, 4), 16) * 0.59 + parseInt(hex.slice(4), 16) * 0.11 < 140;
  const swatch = (hex, i) => new TableCell({ borders, width: { size: w[i], type: WidthType.DXA }, shading: { fill: hex, type: ShadingType.CLEAR, color: 'auto' },
    margins: { top: 60, bottom: 60, left: 100, right: 100 }, children: [new Paragraph({ children: [run('#' + hex, { size: 18, color: dark(hex) ? 'FFFFFF' : '111814' })] })] });
  return new Table({ width: { size: CONTENT_W, type: WidthType.DXA }, columnWidths: w, rows: [
    new TableRow({ tableHeader: true, children: ['Token', 'Light', 'Dark', 'Used for'].map((t, i) => cell(t, i, '0F6B47', true)) }),
    ...tokens.map(([n, l, d, u]) => new TableRow({ children: [cell(n, 0), swatch(l, 1), swatch(d, 2), cell(u, 3)] })),
  ] });
}

const screens = [
  ['01', 'Onboarding', 'figma/01-onboarding.png', 'app/01-onboarding.png',
    'Three swipeable pages explain the value (waste less), the method (snap to add) and the reminder promise. Each page has an animated hero: the SF Symbol bounces when the page becomes active and food emoji float using a phase animator. “Skip” is always available; the final “Get started” requests notification permission in context, which improves opt-in rates compared with asking at launch.',
    ['Paged TabView with page indicator', 'symbolEffect(.bounce) and phaseAnimator', 'Haptic selection feedback when the page changes']],
  ['02', 'Pantry (home)', 'figma/02-pantry.png', 'app/03-pantry.png',
    'The home screen answers one question: “what should I use first?”. A horizontally paged “Needs attention” carousel sits above storage filter chips and a list grouped by urgency (Expired → Use today → Use soon → Fresh). Every row shows the food, storage, quantity, a text status and the freshness ring, so urgency is never conveyed by colour alone.',
    ['Swipe right = Eaten, swipe left = Wasted / Delete', 'Long-press context menu with a large preview card', 'Carousel cards scale and rotate in 3D as they scroll (scrollTransition)', 'Search and sort (expiry, name, recently added)', 'Confetti + success haptic when food is rescued']],
  ['03', 'Item detail', 'figma/03-item-detail.png', 'app/04-item-detail.png',
    'A hero (photo or large emoji on a freshness-tinted gradient) is followed by a status card with a large freshness ring, an information card, a storage tip and “Use it up” recipe ideas. Primary action “I ate it” is the most prominent; Freeze and Wasted are secondary soft buttons. On iPad and in landscape the status and info cards sit side by side (ViewThatFits).',
    ['Pinch to zoom the photo (MagnifyGesture) with spring-back', 'Freeze recalculates expiry from the catalog', 'Edit / Delete in the toolbar menu with confirmation']],
  ['04', 'Scan', 'figma/04-scan.png', 'app/06-scan-results.png',
    'The scan screen uses a segmented control to switch between recognising food and reading a date label. A gradient viewfinder with custom corner-bracket shape shows a sweeping scan line while Vision runs. Results appear as cards with an animated confidence bar and a shelf-life hint; tapping one opens the add form pre-filled.',
    ['Camera (UIImagePickerController) and PhotosPicker', 'Animated ScanningOverlay; respects Reduce Motion', 'Category fallback (e.g. “Fruit”) and “add manually” escape hatch', 'Side-by-side layout in landscape (AnyLayout)']],
  ['05', 'Date label scan', 'figma/06-scan-label.png', 'app/07-label-scan.png',
    'In label mode FreshKeep reads the packaging text on device and shows the best-before date it chose, with a disclosure group that reveals the raw recognised text for transparency.',
    ['Prefers the date after EXP / USE BY over MFD', 'Clear empty state when no date is found']],
  ['06', 'Add / edit item', 'figma/07-add-item.png', 'app/05-add-item.png',
    'A native grouped form. Typing a name shows catalog suggestions as chips; picking one fills category, storage and an expiry estimate. Changing storage re-estimates the date unless the user typed or scanned a real one, and the footer explains where the date came from.',
    ['Invalid save shakes the name field (custom GeometryEffect)', 'Read date from a label photo inside the form', 'Decimal keyboard for price, multi-line notes']],
  ['07', 'Insights', 'figma/08-insights.png', 'app/08-insights.png',
    'A motivational dashboard: a gradient hero with the rescue-rate ring, an adaptive grid of stat tiles (money saved in LKR, items rescued, wasted, CO₂e avoided, streak, money lost), a stacked weekly bar chart, a donut of waste by category and recipe suggestions.',
    ['Swift Charts BarMark and SectorMark, animated on appear', 'Adaptive LazyVGrid (2 columns on iPhone, more on iPad)']],
  ['08', 'Recipe (Use it up)', 'figma/09-recipe.png', 'app/09-insights-recipes.png',
    'Shows which owned ingredients the recipe uses (most urgent first), what else is needed and a tappable step checklist with symbol replace animations.', []],
  ['09', 'Settings', 'figma/10-settings.png', 'app/10-settings.png',
    'Reminder timing, the “use soon” threshold, theme override (System / Light / Dark) and data tools including a destructive erase protected by a confirmation dialog.', []],
];

const children = [
  ...cover({ title: 'FreshKeep', subtitle: 'User interface design and documentation', docType: 'UI Documentation', extra: [['Figma file', FIGMA_URL]] }),
  ...toc(),

  h1('1. Introduction'),
  p('This document describes the user interface of FreshKeep, an iOS app that helps households rescue food before it expires. The interface was designed in **Figma** and then implemented in **SwiftUI**. For each screen the Figma design is shown next to the implemented screen captured from the iOS Simulator by the automated UI tests.'),
  p(`Figma file: ${FIGMA_URL}`),
  table(['Figma page', 'Contents'], [
    ['Style Guide & Components', 'App icon, colour tokens for light and dark, type scale, design principles and the reusable component library.'],
    ['App Screens & Flow', 'iPhone screens built from component instances, dark-mode variants and the navigation flow.'],
    ['visionOS Prototype', 'Window, volumetric fridge and immersive timeline concepts for Part B.'],
  ], [1.3, 3.2]),

  h1('2. Design Process'),
  numbered('**Understand** — defined the problem (forgotten food) and three personas: a working parent, a student and a retired user who prefers large text.'),
  numbered('**Information architecture** — four top-level areas: Pantry, Scan, Insights, Settings. Creating and editing are modal tasks (sheets).'),
  numbered('**Design system** — colour tokens, type scale and components were defined in Figma first so every screen stays consistent.'),
  numbered('**High-fidelity screens** — composed from component instances in Figma.'),
  numbered('**Implementation** — each Figma component maps to a SwiftUI view, modifier or style (Section 4).'),
  numbered('**Validation** — UI tests capture every screen; accessibility checks with Dynamic Type and Dark Mode; user acceptance testing (see Final Report).'),
  h2('2.1 Design principles'),
  table(['Principle', 'How it shows up in the UI'], [
    ['Urgency first', 'Items sorted and grouped by days left; “Needs attention” carousel at the top; freshness colours.'],
    ['One-tap capture', 'Camera + on-device AI pre-fill the form; catalog suggestions while typing.'],
    ['Celebrate rescues', 'Confetti, success haptics, toasts and the Insights impact numbers.'],
    ['Accessible by default', 'System text styles (Dynamic Type), VoiceOver labels, never colour alone, Reduce Motion, 44 pt targets.'],
    ['Native feel', 'Tab bar / sidebar, large titles, grouped forms, SF Symbols, standard gestures.'],
  ], [1.2, 3.3]),

  h1('3. Information Architecture and Navigation'),
  ...image('user-flow.png', 6.3, 'Figure 1 — Navigation and user flow'),
  p('On iPhone the four areas are tabs. On iPad (regular width) the same areas appear in a NavigationSplitView sidebar. Each area has its own NavigationStack, so moving between tabs keeps each tab’s position. Adding and editing happen in sheets, onboarding in a full-screen cover, and destructive actions use confirmation dialogs.'),

  h1('4. Design System'),
  h2('4.1 Colour'),
  p('The palette pairs a leaf-green brand colour with a four-step freshness scale. Every token has a light and a dark value; in the app each colour is an asset-catalog colour with a dark appearance, so Dark Mode switches automatically.'),
  swatches(),
  p(''),
  h2('4.2 Typography'),
  p('The app uses the system font with the rounded design (SF Pro Rounded) through SwiftUI text styles, so every label follows the user’s Dynamic Type size. Figma’s cloud renderer cannot draw SF fonts, so the Figma file uses Nunito (a similar rounded typeface) as a stand-in, and Material Symbols Rounded stands in for SF Symbols.'),
  table(['Style', 'Size / weight', 'Used for'], [
    ['Large Title', '34 pt Bold', 'Screen titles'], ['Title 2', '22 pt Bold', 'Card headings, item status'], ['Title 3', '20 pt Semibold', 'Section headings'],
    ['Headline', '17 pt Semibold', 'Row titles, buttons'], ['Body', '17 pt Regular', 'Text and form fields'], ['Subheadline', '15 pt Regular', 'Secondary text'],
    ['Footnote / Caption', '13 / 12 pt', 'Hints, metadata, chart labels'],
  ], [1.3, 1.3, 2]),
  h2('4.3 Spacing, shape and elevation'),
  p('A 4-point grid (4, 8, 12, 16, 24) is used for padding and gaps. Cards have a 20 pt continuous corner radius, buttons 16 pt and chips are capsules. Cards use a soft shadow in light mode only; in dark mode elevation comes from the lighter card colour.'),
  h2('4.4 Components'),
  table(['Figma component', 'SwiftUI implementation', 'Behaviour'], [
    ['Freshness Ring (Fresh / Use soon / Today / Expired)', '`FreshnessRing` custom view', 'Animated trim, colour by level, days label, @ScaledMetric size, VoiceOver value'],
    ['Button (Primary / Soft)', '`PrimaryButtonStyle`, `SoftButtonStyle`', 'Spring scale to 0.96 while pressed; disabled opacity'],
    ['Filter Chip (selected / default)', '`FilterChip`', 'Capsule with icon and count; selected trait for VoiceOver'],
    ['Pantry Row', '`PantryRow`', 'Thumbnail, name, storage, status text, ring; swipe + context menu'],
    ['Stat Tile', '`StatTile`', 'Icon tile, value and caption, scales down long values'],
    ['Scan Match Row', '`MatchRow`', 'Emoji, name, confidence %, animated bar, shelf-life hint'],
    ['Tab Bar', '`TabView` / `NavigationSplitView`', 'Tab bar on iPhone, sidebar on iPad'],
    ['Card', '`.freshCard()` view modifier', 'Padding, card colour, radius, light-mode shadow'],
  ], [1.6, 1.5, 2]),
  ...(has('figma/components.png') ? image('figma/components.png', 6.3, 'Figure 2 — Component library in Figma') : []),

  pageBreak(),
  h1('5. Screens'),
  ...screens.flatMap(([num, name, fig, app, text, bullets]) => [
    h2(`5.${parseInt(num, 10)} ${name}`),
    ...pair(fig, app, `Figure — ${name}`),
    p(text),
    ...bullets.map((b) => bullet(b)),
  ]),

  h1('6. Adaptive Layout, Dark Mode and Dynamic Type'),
  p('FreshKeep adapts to the device and the user’s settings:'),
  bullet('**Size classes** — compact width uses a tab bar; regular width uses a sidebar (NavigationSplitView). Detail and Insights limit their content width to stay readable on iPad.'),
  bullet('**Orientation** — the scan screen switches from a vertical to a horizontal layout in landscape using AnyLayout; detail cards sit side by side with ViewThatFits.'),
  bullet('**Dark Mode** — all colours are dynamic assets; shadows are removed in dark mode; the theme can be forced in Settings.'),
  bullet('**Dynamic Type** — all text uses text styles; the freshness ring and thumbnails scale with @ScaledMetric (capped so layouts do not break at accessibility sizes).'),
  ...(has('app/11-dark-large-text.png') ? image('app/11-dark-large-text.png', 2.4, 'Figure — Pantry in Dark Mode with accessibility text size (AX Large)') : []),

  h1('7. Accessibility Checklist'),
  table(['Check', 'Status', 'Notes'], [
    ['VoiceOver labels for every control', 'Done', 'Rows combine name, storage and status; ring exposes level and days left'],
    ['Information not by colour alone', 'Done', 'Every freshness colour is paired with text (“Use today”, “2 days left”)'],
    ['Dynamic Type up to accessibility sizes', 'Done', 'System text styles; verified with AX Large in UI tests'],
    ['Contrast ≥ 4.5:1 for text', 'Done', 'Primary/secondary text tokens meet AA on background and card colours'],
    ['Touch targets ≥ 44 pt', 'Done', 'Buttons 44–50 pt high; rows full width'],
    ['Reduce Motion', 'Done', 'Ring and scan line animations are skipped when enabled'],
    ['Announcements', 'Done', 'Toasts are announced with UIAccessibility.post'],
  ], [2, 0.7, 2.6]),

  h1('8. visionOS Interface (Part B)'),
  p('FreshKeep Spatial follows the visionOS Human Interface Guidelines: a glass window with a sidebar list and detail, an ornament holding the main actions, a volumetric window with 3D content, and a mixed immersive space. Interactive 3D items have input-target and hover-effect components so the system highlights what the user looks at. Text never floats without a glass background to keep it legible against the room.'),
  ...(has('visionos-main.png') ? image('visionos-main.png', 6.0, 'Figure — FreshKeep Spatial main window in the Apple Vision Pro simulator') : [note('visionOS screenshot')]),
];

build(path.join(__dirname, '..', 'FreshKeep_UI_Documentation_IT21244384.docx'), children, 'UI Documentation');
