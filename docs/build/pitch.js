// FreshKeep Spatial — investor pitch deck (Assignment Part B).
const fs = require('fs');
const path = require('path');
const pptxgen = require('pptxgenjs');
const { applyTheme } = require('./apply_theme.js');

const IMG = path.join(__dirname, '..', 'images');
const OUT = path.join(__dirname, '..', 'FreshKeep_Spatial_Pitch_IT21244384.pptx');

const THEME = {
  name: 'FreshKeep',
  headFontFace: 'Calibri',
  bodyFontFace: 'Calibri',
  colors: {
    dk1: '111814', lt1: 'FFFFFF', dk2: '0F6B47', lt2: 'EEF5F0',
    accent1: '2BAE66', accent2: 'F5A524', accent3: 'EF6C2F', accent4: 'D93D3D', accent5: '5F6B64', accent6: '9AD9B4',
    hlink: '2BAE66', folHlink: '0F6B47',
  },
};

const pres = new pptxgen();
pres.layout = 'LAYOUT_WIDE'; // 13.33 x 7.5
pres.title = 'FreshKeep Spatial — Pitch';
pres.author = 'Abisheak S (IT21244384)';
pres.theme = { headFontFace: THEME.headFontFace, bodyFontFace: THEME.bodyFontFace };
const C = pres.SchemeColor;

pres.defineSlideMaster({
  title: 'DARK',
  background: { color: THEME.colors.dk2 },
  objects: [
    { placeholder: { options: { name: 'title', type: 'title', x: 0.7, y: 2.3, w: 8.6, h: 1.6, fontSize: 50, bold: true, color: C.background1, valign: 'bottom', align: 'left', margin: 0 }, text: '' } },
    { placeholder: { options: { name: 'body', type: 'body', x: 0.7, y: 4.0, w: 8.6, h: 1.2, fontSize: 22, color: 'C8E8D4', valign: 'top', align: 'left', margin: 0 }, text: '' } },
  ],
});
pres.defineSlideMaster({
  title: 'CONTENT',
  background: { color: 'FFFFFF' },
  margin: [0.5, 0.6, 0.6, 0.6],
  slideNumber: { x: 12.4, y: 7.0, w: 0.5, h: 0.3, fontSize: 11, color: '5F6B64' },
  objects: [
    { placeholder: { options: { name: 'title', type: 'title', x: 0.6, y: 0.4, w: 12.1, h: 0.9, fontSize: 36, bold: true, color: C.text2, valign: 'middle', margin: 0 }, text: '' } },
    { text: { text: 'FreshKeep Spatial', options: { x: 0.6, y: 7.0, w: 4, h: 0.3, fontSize: 11, color: '5F6B64', margin: 0 } } },
  ],
});

const notes = (s, t) => s.addNotes(t);
let n = 0;
const card = (slide, x, y, w, h, fill = 'EEF5F0') => slide.addShape(pres.shapes.ROUNDED_RECTANGLE, {
  x, y, w, h, rectRadius: 0.18, fill: { color: fill }, line: { color: fill }, objectName: `card-${++n}`,
});
const iconCircle = (slide, x, y, emoji, fill = THEME.colors.accent1, d = 0.75) => {
  slide.addShape(pres.shapes.OVAL, { x, y, w: d, h: d, fill: { color: fill }, line: { color: fill }, objectName: `icon-bg-${++n}` });
  slide.addText(emoji, { x, y, w: d, h: d, fontSize: d * 26, align: 'center', valign: 'middle', margin: 0, isTextBox: true, objectName: `icon-${n}` });
};
const text = (slide, t, opts) => slide.addText(t, { isTextBox: true, margin: 0, color: THEME.colors.dk1, fontSize: 16, valign: 'top', ...opts, objectName: `t-${++n}` });
const img = (slide, file, opts) => { const f = path.join(IMG, file); if (fs.existsSync(f)) slide.addImage({ path: f, ...opts, objectName: `img-${++n}` }); else { card(slide, opts.x, opts.y, opts.w, opts.h, 'E9EEE6'); text(slide, `[${file}]`, { x: opts.x, y: opts.y + opts.h / 2 - 0.2, w: opts.w, h: 0.4, align: 'center', color: '5F6B64' }); } };

// 1. Title
pres.addSection({ title: 'Opening' });
{ const s = pres.addSlide({ masterName: 'DARK', sectionTitle: 'Opening' });
  s.addText('FreshKeep Spatial', { placeholder: 'title' });
  s.addText('Your whole kitchen, at a glance — so nothing goes to waste', { placeholder: 'body' });
  img(s, 'app-icon.png', { x: 9.6, y: 2.0, w: 2.9, h: 2.9, rounding: true });
  text(s, 'Abisheak S · IT21244384 · SE4041 Assignment 02 — Part B (visionOS)', { x: 0.7, y: 6.6, w: 9, h: 0.4, fontSize: 14, color: 'C8E8D4' });
  notes(s, 'Hi, I am Abisheak. FreshKeep Spatial is a visionOS app that lets people see everything in their kitchen in 3D and rescue food before it expires.'); }

// 2. Problem
pres.addSection({ title: 'Problem' });
{ const s = pres.addSlide({ masterName: 'CONTENT', sectionTitle: 'Problem' });
  s.addText('Households throw away food they forgot they had', { placeholder: 'title' });
  card(s, 0.6, 1.6, 5.6, 4.9, 'EEF5F0');
  text(s, '79 kg', { x: 1.0, y: 2.0, w: 4.8, h: 1.4, fontSize: 80, bold: true, color: THEME.colors.dk2 });
  text(s, 'of food wasted per person, per year, at home (UNEP Food Waste Index 2024)', { x: 1.0, y: 3.5, w: 4.8, h: 1.0, fontSize: 18, color: '5F6B64' });
  text(s, 'Households are the single largest source of food waste.', { x: 1.0, y: 4.8, w: 4.8, h: 1.0, fontSize: 18, bold: true });
  const rows = [['🙈', 'Out of sight, out of mind', 'Food at the back of the fridge is forgotten until it smells.'],
    ['⌨️', 'Tracking apps are tedious', 'Typing every item and date by hand — people give up in days.'],
    ['🤷', 'No idea what to use first', 'Nothing tells you which food is about to expire today.']];
  rows.forEach(([e, h, b], i) => { const y = 1.7 + i * 1.6; iconCircle(s, 6.8, y, e, i === 0 ? THEME.colors.accent3 : THEME.colors.accent2);
    text(s, h, { x: 7.8, y, w: 4.9, h: 0.45, fontSize: 20, bold: true });
    text(s, b, { x: 7.8, y: y + 0.5, w: 4.9, h: 0.8, fontSize: 16, color: '5F6B64' }); });
  notes(s, 'The problem is forgetting. UNEP estimates 79 kg per person per year is wasted at home. Existing apps fail because data entry is boring.'); }

// 3. Why spatial
{ const s = pres.addSlide({ masterName: 'CONTENT', sectionTitle: 'Problem' });
  s.addText('Why spatial computing?', { placeholder: 'title' });
  const items = [['🧊', 'Kitchens are physical spaces', 'A 3D fridge you can look into beats a scrolling list.'],
    ['👀', 'Glanceable urgency', 'Colour and distance show what expires first — no reading needed.'],
    ['🙌', 'Hands-free while cooking', 'Look and pinch with messy hands; no phone to unlock.'],
    ['🏠', 'Made for the home', 'Vision Pro is used at home, where the food decisions happen.']];
  items.forEach(([e, h, b], i) => { const x = 0.6 + (i % 2) * 6.15; const y = 1.6 + Math.floor(i / 2) * 2.55;
    card(s, x, y, 5.95, 2.3); iconCircle(s, x + 0.35, y + 0.35, e);
    text(s, h, { x: x + 1.35, y: y + 0.35, w: 4.4, h: 0.5, fontSize: 20, bold: true });
    text(s, b, { x: x + 1.35, y: y + 0.95, w: 4.4, h: 1.1, fontSize: 16, color: '5F6B64' }); });
  notes(s, 'Spatial computing turns an invisible problem into something you can see.'); }

// 4. Solution
pres.addSection({ title: 'Solution' });
{ const s = pres.addSlide({ masterName: 'CONTENT', sectionTitle: 'Solution' });
  s.addText('Three spatial experiences', { placeholder: 'title' });
  const items = [['🪟', 'Glass window', 'Pantry grouped by urgency, item details and recipe ideas. Ornament launches the spatial modes.', THEME.colors.accent1],
    ['🧊', '3D virtual fridge (volume)', 'Shelves for fridge, counter, pantry and freezer. Items are tokens coloured by freshness. Pinch to inspect; drag into the pot to cook.', THEME.colors.accent2],
    ['🕰️', 'Expiry timeline (immersive)', 'Food floats on an arc around you in your real kitchen — the closer it is, the sooner it expires.', THEME.colors.accent3]];
  items.forEach(([e, h, b, col], i) => { const x = 0.6 + i * 4.1;
    card(s, x, 1.6, 3.9, 4.9); iconCircle(s, x + 0.35, 1.95, e, col, 0.95);
    text(s, h, { x: x + 0.35, y: 3.15, w: 3.2, h: 0.9, fontSize: 21, bold: true });
    text(s, b, { x: x + 0.35, y: 4.1, w: 3.2, h: 2.2, fontSize: 16, color: '5F6B64' }); });
  notes(s, 'The prototype has three scenes. All share the same data as the iPhone app.'); }

// 5. Prototype
{ const s = pres.addSlide({ masterName: 'CONTENT', sectionTitle: 'Solution' });
  s.addText('Working prototype on visionOS', { placeholder: 'title' });
  img(s, 'visionos-window.png', { x: 0.6, y: 1.55, w: 7.7, h: 5.04 });
  const pts = [['RealityKit volume', 'generated 3D shelves, tokens and pot — no asset files'],
    ['Spatial gestures', 'SpatialTapGesture + DragGesture targeted to entities'],
    ['Attachments', 'SwiftUI glass cards floating above 3D items'],
    ['Shared data', 'same SwiftData model + FreshKeepCore package as iOS'],
    ['Verified in CI', 'built and launched in the Vision Pro simulator on every push']];
  pts.forEach(([h, b], i) => { const y = 1.6 + i * 1.02; text(s, h, { x: 8.6, y, w: 4.2, h: 0.4, fontSize: 18, bold: true, color: THEME.colors.dk2 });
    text(s, b, { x: 8.6, y: y + 0.4, w: 4.2, h: 0.55, fontSize: 14, color: '5F6B64' }); });
  notes(s, 'Demo: open the fridge volume, pinch a banana to see its card, drag it into the pot. Then open the expiry timeline.'); }

// 6. Interaction design
{ const s = pres.addSlide({ masterName: 'CONTENT', sectionTitle: 'Solution' });
  s.addText('Designed for eyes and hands', { placeholder: 'title' });
  const rows = [['Look + pinch', 'Select an item; hover highlight shows what you are looking at', '👁️'],
    ['Pinch + drag', 'Pick food up and drop it into the Cook-now pot to log it as eaten', '🤏'],
    ['Ornaments', 'Primary actions float below the window, following Apple HIG', '🧭'],
    ['Glass & depth', 'System glass materials keep the room visible and comfortable', '🔮'],
    ['Comfort', 'Content at 0.8 – 2.2 m, mixed immersion, no forced motion', '🧘']];
  rows.forEach(([h, b, e], i) => { const y = 1.55 + i * 1.05; iconCircle(s, 0.6, y, e, i % 2 ? THEME.colors.accent2 : THEME.colors.accent1, 0.8);
    text(s, h, { x: 1.65, y: y + 0.05, w: 3.0, h: 0.7, fontSize: 20, bold: true, valign: 'middle' });
    text(s, b, { x: 4.7, y: y + 0.05, w: 8.0, h: 0.7, fontSize: 16, color: '5F6B64', valign: 'middle' }); });
  notes(s, 'Every interaction maps to the native visionOS input model: look, pinch, drag.'); }

// 7. Competition
pres.addSection({ title: 'Market' });
{ const s = pres.addSlide({ masterName: 'CONTENT', sectionTitle: 'Market' });
  s.addText('Existing apps solve only part of it', { placeholder: 'title' });
  const hdr = (t) => ({ text: t, options: { bold: true, color: 'FFFFFF', fill: { color: THEME.colors.dk2 } } });
  const rows = [
    [hdr('Product'), hdr('Platform'), hdr('What it does'), hdr('Gap')],
    ['Crouton', 'iOS, visionOS', 'Recipe manager and cooking mode', 'No pantry or expiry awareness'],
    ["Lowe's Style Studio", 'visionOS', 'Design a kitchen spatially', 'Kitchen layout, not food'],
    ['Smart fridges with cameras', 'Appliance', 'Look inside the fridge remotely', 'Expensive hardware; fridge only'],
    ['NoWaste / Fridgely', 'iOS', 'Manual inventory and expiry lists', 'Typing; not spatial'],
    [{ text: 'FreshKeep Spatial', options: { bold: true, color: THEME.colors.dk2 } }, 'iOS + visionOS', 'AI capture on iPhone, 3D pantry & timeline on Vision Pro', { text: 'Whole kitchen, urgency-first', options: { bold: true, color: THEME.colors.dk2 } }],
  ];
  s.addTable(rows, { x: 0.6, y: 1.6, w: 12.1, colW: [2.6, 2.0, 4.0, 3.5], fontSize: 15, color: THEME.colors.dk1, border: { type: 'solid', color: 'D5DED8', pt: 1 }, rowH: 0.75, valign: 'middle', objectName: 'competition' });
  notes(s, 'Competitors either do recipes, kitchen design or need special hardware. Nobody makes the food itself visible and urgent.'); }

// 8. Target market
{ const s = pres.addSlide({ masterName: 'CONTENT', sectionTitle: 'Market' });
  s.addText('Who it is for', { placeholder: 'title' });
  const rings = [['Beachhead', 'FreshKeep iPhone users who own an Apple Vision Pro — early adopters, home cooks', 2.6, THEME.colors.dk2],
    ['Expansion', 'All Vision Pro households; families who share a kitchen', 4.0, THEME.colors.accent1],
    ['Long term', 'Lighter, cheaper headsets and smart-home partners', 5.4, 'A7DCC0']];
  [...rings].reverse().forEach(([, , d, col]) => s.addShape(pres.shapes.OVAL, { x: 3.7 - d / 2, y: 4.4 - d / 2, w: d, h: d, fill: { color: col }, line: { color: 'FFFFFF', width: 2 }, objectName: `ring-${++n}` }));
  text(s, 'Beachhead', { x: 2.2, y: 4.15, w: 3.0, h: 0.5, fontSize: 18, bold: true, color: 'FFFFFF', align: 'center' });
  text(s, 'Expansion', { x: 2.2, y: 2.7, w: 3.0, h: 0.4, fontSize: 16, bold: true, color: 'FFFFFF', align: 'center' });
  text(s, 'Long term', { x: 2.2, y: 2.0, w: 3.0, h: 0.4, fontSize: 15, bold: true, color: THEME.colors.dk2, align: 'center' });
  rings.forEach(([h, b], i) => { const y = 1.7 + i * 1.6; text(s, h, { x: 7.6, y, w: 5.1, h: 0.45, fontSize: 20, bold: true, color: THEME.colors.dk2 });
    text(s, b, { x: 7.6, y: y + 0.5, w: 5.1, h: 0.9, fontSize: 16, color: '5F6B64' }); });
  notes(s, 'We start with people who already use FreshKeep on iPhone and own a Vision Pro, then grow as headsets get cheaper.'); }

// 9. Revenue model
pres.addSection({ title: 'Business' });
{ const s = pres.addSlide({ masterName: 'CONTENT', sectionTitle: 'Business' });
  s.addText('Revenue model: freemium + partnerships', { placeholder: 'title' });
  const tiers = [['Free', 'iPhone app', ['Scan food & labels', 'Reminders', 'Insights'], 'EEF5F0', THEME.colors.dk1],
    ['FreshKeep Plus', 'USD 2.99 / month · USD 24.99 / year (proposed)', ['Spatial fridge & timeline', 'Household sharing & iCloud sync', 'Premium recipe packs'], THEME.colors.dk2, 'FFFFFF'],
    ['Partners', 'B2B (future)', ['Grocery partners: “use it up” offers', 'Appliance makers: licensed spatial view', 'Anonymised waste insights for NGOs'], 'FFF4E0', THEME.colors.dk1]];
  tiers.forEach(([h, sub, list, fill, col], i) => { const x = 0.6 + i * 4.1;
    card(s, x, 1.6, 3.9, 4.9, fill);
    text(s, h, { x: x + 0.35, y: 1.9, w: 3.2, h: 0.6, fontSize: 26, bold: true, color: col });
    text(s, sub, { x: x + 0.35, y: 2.55, w: 3.2, h: 0.8, fontSize: 14, color: col === 'FFFFFF' ? 'C8E8D4' : '5F6B64' });
    s.addText(list.map((t, j) => ({ text: t, options: { bullet: true, breakLine: j < list.length - 1 } })), { x: x + 0.35, y: 3.5, w: 3.3, h: 2.6, fontSize: 16, color: col, paraSpaceAfter: 8, valign: 'top', margin: 0, isTextBox: true, objectName: `tier-${i}` }); });
  notes(s, 'The iPhone app stays free to build habit. Spatial features are part of a Plus subscription. Later, partnerships with grocers and appliance makers.'); }

// 10. Go to market
{ const s = pres.addSlide({ masterName: 'CONTENT', sectionTitle: 'Business' });
  s.addText('Go-to-market plan', { placeholder: 'title' });
  const steps = [['1', 'Launch iOS', 'Free on the App Store; campus and sustainability communities in Sri Lanka'],
    ['2', 'Add Spatial', 'Release FreshKeep Plus with the visionOS app; App Store feature pitch'],
    ['3', 'Build proof', 'Publish rescue stats; partner with food-waste NGOs and cooking creators'],
    ['4', 'Partner', 'Pilot "use it up" offers with grocers; explore appliance licensing']];
  s.addShape(pres.shapes.LINE, { x: 1.2, y: 3.15, w: 10.9, h: 0, line: { color: THEME.colors.accent1, width: 3 }, objectName: 'timeline' });
  steps.forEach(([num, h, b], i) => { const x = 0.6 + i * 3.1;
    s.addShape(pres.shapes.OVAL, { x: x + 0.3, y: 2.75, w: 0.8, h: 0.8, fill: { color: THEME.colors.dk2 }, line: { color: 'FFFFFF', width: 3 }, objectName: `step-${i}` });
    text(s, num, { x: x + 0.3, y: 2.75, w: 0.8, h: 0.8, fontSize: 24, bold: true, color: 'FFFFFF', align: 'center', valign: 'middle' });
    text(s, h, { x, y: 3.85, w: 2.9, h: 0.5, fontSize: 20, bold: true, color: THEME.colors.dk2 });
    text(s, b, { x, y: 4.4, w: 2.8, h: 1.8, fontSize: 15, color: '5F6B64' }); });
  notes(s, 'iOS first to grow users cheaply, then the spatial app as the premium differentiator.'); }

// 11. Tech
pres.addSection({ title: 'Technology' });
{ const s = pres.addSlide({ masterName: 'CONTENT', sectionTitle: 'Technology' });
  s.addText('Built to scale across Apple platforms', { placeholder: 'title' });
  img(s, 'architecture.png', { x: 0.6, y: 1.5, w: 7.2, h: 5.04 });
  const pts = ['One Swift package shared by iPhone and Vision Pro', 'SwiftData model shared by both apps', 'On-device Vision AI — private and offline', 'RealityKit entities generated in code (small app size)', '50+ automated tests run on every push'];
  s.addText(pts.map((t, j) => ({ text: t, options: { bullet: true, breakLine: j < pts.length - 1 } })), { x: 8.2, y: 1.7, w: 4.5, h: 4.5, fontSize: 17, color: THEME.colors.dk1, paraSpaceAfter: 14, valign: 'top', margin: 0, isTextBox: true, objectName: 'tech-points' });
  notes(s, 'The same core code powers both apps, so features ship to both platforms at once.'); }

// 12. Impact & next steps
{ const s = pres.addSlide({ masterName: 'CONTENT', sectionTitle: 'Technology' });
  s.addText('Impact and roadmap', { placeholder: 'title' });
  const stats = [['Less waste', 'Urgency-first view and reminders target the main cause: forgetting'], ['Money saved', 'Every rescued item is tracked in LKR so users see the benefit'], ['Lower emissions', 'Rescued food avoids its CO₂e footprint']];
  stats.forEach(([h, b], i) => { const y = 1.6 + i * 1.6; card(s, 0.6, y, 5.6, 1.4);
    text(s, h, { x: 0.95, y: y + 0.2, w: 5.0, h: 0.5, fontSize: 20, bold: true, color: THEME.colors.dk2 });
    text(s, b, { x: 0.95, y: y + 0.7, w: 5.0, h: 0.6, fontSize: 15, color: '5F6B64' }); });
  const road = ['Anchor labels to the real fridge with object tracking', 'SharePlay household mode: plan meals together', 'Custom Core ML model for local produce (jackfruit, gotukola)', 'Apple TV / iPad kitchen dashboards'];
  text(s, 'Next', { x: 6.9, y: 1.6, w: 5.8, h: 0.5, fontSize: 22, bold: true, color: THEME.colors.dk2 });
  s.addText(road.map((t, j) => ({ text: t, options: { bullet: true, breakLine: j < road.length - 1 } })), { x: 6.9, y: 2.2, w: 5.8, h: 4.0, fontSize: 17, color: THEME.colors.dk1, paraSpaceAfter: 14, valign: 'top', margin: 0, isTextBox: true, objectName: 'roadmap' });
  notes(s, 'Next steps make the experience even more physical: labels attached to the real fridge.'); }

// 13. Close
pres.addSection({ title: 'Close' });
{ const s = pres.addSlide({ masterName: 'DARK', sectionTitle: 'Close' });
  s.addText('See it. Save it.', { placeholder: 'title' });
  s.addText('Thank you — questions?', { placeholder: 'body' });
  text(s, 'github.com/IT21244384/SE4041-FreshKeep', { x: 0.7, y: 6.6, w: 9, h: 0.4, fontSize: 14, color: 'C8E8D4' });
  img(s, 'app-icon.png', { x: 9.6, y: 2.0, w: 2.9, h: 2.9, rounding: true });
  notes(s, 'Thank you. Happy to take questions or show the prototype again.'); }

(async () => {
  await pres.writeFile({ fileName: OUT });
  await applyTheme(OUT, THEME);
  console.log('Wrote', OUT);
})();
