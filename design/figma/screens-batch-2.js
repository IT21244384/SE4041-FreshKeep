// FreshKeep — Figma Plugin API script: iPhone screens 04–10 (Scan, Scan results, Label scan,
// Add item, Insights, Recipe, Settings). Appends to section 7:6 on page 1:7.
// Component ids refer to the Style Guide page of file XzRIMOQaZ2idUztQPhRcZC.
const page = await figma.getNodeByIdAsync('1:7'); await figma.setCurrentPageAsync(page);
for (const st of ['Regular','SemiBold','Bold','ExtraBold']) await figma.loadFontAsync({family:'Nunito',style:st});
await figma.loadFontAsync({family:'Material Symbols Rounded',style:'Bold'});
await figma.loadFontAsync({family:'Inter',style:'Medium'});
const tstyles = await figma.getLocalTextStylesAsync(); const S = n=>tstyles.find(s=>s.name==='FreshKeep/'+n);
const vars = await figma.variables.getLocalVariablesAsync('COLOR'); const V = n => vars.find(v=>v.name==='light/'+n);
const P = (n, op=1) => { if (op<1) { const c = Object.values(V(n).valuesByMode)[0]; return {type:'SOLID',color:{r:c.r,g:c.g,b:c.b},opacity:op}; } return figma.variables.setBoundVariableForPaint({type:'SOLID',color:{r:0,g:0,b:0}},'color',V(n)); };
const shadow = (await figma.getLocalEffectStylesAsync())[0];
const txt = async (str, style, color='text/primary', w) => { const t=figma.createText(); await t.setTextStyleIdAsync(S(style).id); t.characters=str; t.fills=[P(color)]; if(w){t.textAutoResize='HEIGHT'; t.resize(w,t.height);} else t.textAutoResize='WIDTH_AND_HEIGHT'; return t; };
const icon = (name, size, color='text/primary') => { const t=figma.createText(); t.fontName={family:'Material Symbols Rounded',style:'Bold'}; t.fontSize=size; t.characters=name; t.fills=[P(color)]; t.textAutoResize='WIDTH_AND_HEIGHT'; t.name='Icon: '+name; return t; };
const AL = (dir, props={}) => { const f = figma.createAutoLayout(dir, props); f.fills=[]; return f; };
const fill = (n) => { n.layoutSizingHorizontal='FILL'; return n; };
const card = (dir='VERTICAL', pad=16, gap=12) => { const c = AL(dir,{itemSpacing:gap}); c.fills=[P('surface/card')]; c.cornerRadius=20; c.paddingLeft=c.paddingRight=c.paddingTop=c.paddingBottom=pad; return c; };
const comps = { ring: await figma.getNodeByIdAsync('4:26'), btn: await figma.getNodeByIdAsync('4:33'), chip: await figma.getNodeByIdAsync('4:40'), row: await figma.getNodeByIdAsync('4:41'), stat: await figma.getNodeByIdAsync('4:53'), tab: await figma.getNodeByIdAsync('4:58'), match: await figma.getNodeByIdAsync('4:71') };
const variant = (set, props) => set.children.find(c => Object.entries(props).every(([k,v]) => c.name.includes(`${k}=${v}`)));
const setText = (inst, name, value, color) => { const t = inst.findOne(n=>n.type==='TEXT' && n.name===name); t.characters = value; if (color) t.fills=[P(color)]; return t; };
const sec = await figma.getNodeByIdAsync('7:6');
let sx = Math.max(...sec.children.map(c=>c.x+c.width)) + 100;
const screen = async (name) => {
  const f = figma.createFrame(); f.name=name; f.resize(393,852); f.fills=[P('surface/background')]; f.clipsContent=true; f.cornerRadius=44;
  const sb = AL('HORIZONTAL'); sb.name='Status Bar'; sb.resize(393,54); sb.primaryAxisSizingMode='FIXED'; sb.counterAxisSizingMode='FIXED'; sb.primaryAxisAlignItems='SPACE_BETWEEN'; sb.counterAxisAlignItems='CENTER'; sb.paddingLeft=sb.paddingRight=32; sb.paddingTop=10;
  sb.appendChild(await txt('9:41','Headline')); const r = AL('HORIZONTAL',{itemSpacing:4}); for (const i of ['signal_cellular_alt','wifi','battery_full']) r.appendChild(icon(i,17)); sb.appendChild(r);
  f.appendChild(sb); sb.x=0; sb.y=0;
  const body = AL('VERTICAL',{name:'Content', itemSpacing:16}); body.paddingLeft=body.paddingRight=16; body.resize(393,10); body.primaryAxisSizingMode='AUTO'; body.counterAxisSizingMode='FIXED';
  f.appendChild(body); body.x=0; body.y=54;
  sec.appendChild(f); f.x=sx; f.y=120; sx += 393+100;
  return {f, body};
};
const tabBar = (f, active) => { const t = comps.tab.createInstance(); f.appendChild(t); t.x=0; t.y=852-83;
  for (const it of t.children) { const on = it.name===active; for (const c of it.children) c.fills=[P(on?'brand/primary':'text/secondary')]; } return t; };
const segmented = async (items, sel) => { const s = AL('HORIZONTAL',{itemSpacing:0}); s.fills=[P('surface/chip')]; s.cornerRadius=10; s.paddingLeft=s.paddingRight=s.paddingTop=s.paddingBottom=2;
  for (const it of items) { const o = AL('HORIZONTAL'); o.primaryAxisAlignItems='CENTER'; o.paddingTop=o.paddingBottom=6; o.cornerRadius=8; if (it===sel) { o.fills=[P('surface/card')]; await o.setEffectStyleIdAsync(shadow.id); } o.appendChild(await txt(it,'Subheadline Semibold')); s.appendChild(o); fill(o); } return s; };
const viewfinder = async (content) => { const v = AL('VERTICAL',{itemSpacing:12}); v.name='Viewfinder'; v.primaryAxisAlignItems='CENTER'; v.counterAxisAlignItems='CENTER'; v.resize(361,271); v.primaryAxisSizingMode='FIXED'; v.cornerRadius=28; v.clipsContent=true;
  v.fills=[{type:'GRADIENT_LINEAR',gradientTransform:[[0.7,0.7,0],[-0.7,0.7,0.5]],gradientStops:[{position:0,color:{r:0.17,g:0.68,b:0.4,a:1}},{position:1,color:{r:0.06,g:0.42,b:0.28,a:1}}]}];
  for (const n of content) v.appendChild(n);
  for (const [x,y,r] of [[16,16,0],[305,16,90],[305,215,180],[16,215,270]]) { const b = figma.createVector(); await b.setVectorNetworkAsync({vertices:[{x:0,y:40},{x:0,y:14,},{x:14,y:0},{x:40,y:0}],segments:[{start:0,end:1},{start:1,end:2,tangentStart:{x:0,y:-8},tangentEnd:{x:-8,y:0}},{start:2,end:3}]}); b.strokes=[{type:'SOLID',color:{r:1,g:1,b:1}}]; b.strokeWeight=4; b.strokeCap='ROUND'; v.appendChild(b); b.layoutPositioning='ABSOLUTE'; b.rotation=-r; b.x = x + (r===90||r===180?40:0); b.y = y + (r===180||r===270?40:0); }
  return v; };
const ids = [];
const titleBar = async (body, title) => { body.appendChild(await txt(title,'Large Title')); };

// 4. Scan empty
{ const {f, body} = await screen('04 Scan'); await titleBar(body,'Scan');
  const seg = await segmented(['Food','Date label'],'Food'); body.appendChild(seg); fill(seg);
  const vf = await viewfinder([icon('center_focus_strong',60,'text/on-brand'), await txt('Point at fruit, veg or groceries','Headline','text/on-brand')]); body.appendChild(vf); fill(vf);
  const btns = AL('HORIZONTAL',{itemSpacing:12}); body.appendChild(btns); fill(btns);
  const b1 = variant(comps.btn,{Style:'Primary'}).createInstance(); setText(b1,'Label','Camera'); b1.findOne(n=>n.name.startsWith('Icon')).characters='photo_camera'; btns.appendChild(b1); fill(b1);
  const b2 = variant(comps.btn,{Style:'Soft'}).createInstance(); setText(b2,'Label','Photos'); b2.findOne(n=>n.name.startsWith('Icon')).characters='photo_library'; btns.appendChild(b2); fill(b2);
  const hint = card('VERTICAL',16,8); body.appendChild(hint); fill(hint);
  const hh = AL('HORIZONTAL',{itemSpacing:8}); hh.counterAxisAlignItems='CENTER'; hh.appendChild(icon('lock',20,'brand/primary')); hh.appendChild(await txt('Private, on-device AI','Headline')); hint.appendChild(hh);
  hint.appendChild(await txt('Apple Vision recognises the food on your iPhone. Photos never leave your device and it works offline.','Subheadline','text/secondary',329));
  body.appendChild(await txt('Try a sample photo','Subheadline Semibold','brand/primary'));
  tabBar(f,'Scan'); ids.push(f.id); }

// 5. Scan results
{ const {f, body} = await screen('05 Scan Results'); await titleBar(body,'Scan');
  const seg = await segmented(['Food','Date label'],'Food'); body.appendChild(seg); fill(seg);
  const photo = AL('VERTICAL'); photo.primaryAxisAlignItems='CENTER'; photo.counterAxisAlignItems='CENTER'; photo.resize(361,200); photo.primaryAxisSizingMode='FIXED'; photo.cornerRadius=28; photo.fills=[{type:'SOLID',color:{r:0.98,g:0.95,b:0.86}}];
  const ph = await txt('🍌','Large Title'); ph.fontSize=120; ph.lineHeight={unit:'PIXELS',value:140}; photo.appendChild(ph); body.appendChild(photo); fill(photo);
  body.appendChild(await txt('Is it one of these?','Title 3'));
  const m1 = comps.match.createInstance(); body.appendChild(m1); fill(m1);
  const m2 = comps.match.createInstance(); setText(m2,'Emoji','🥭'); setText(m2,'Name','Mango'); setText(m2,'Confidence','34%'); setText(m2,'Hint','Keeps ~4 days on the counter'); m2.findOne(n=>n.name==='Fill').resize(75,8); body.appendChild(m2); fill(m2);
  const m3 = comps.match.createInstance(); setText(m3,'Emoji','🍽️'); setText(m3,'Name','Fruit'); setText(m3,'Confidence','95%'); setText(m3,'Hint','Category only — choose the exact food'); m3.findOne(n=>n.name==='Fill').resize(210,8); body.appendChild(m3); fill(m3);
  body.appendChild(await txt('None of these — add manually','Subheadline','brand/primary'));
  tabBar(f,'Scan'); ids.push(f.id); }

// 6. Label scan
{ const {f, body} = await screen('06 Scan Date Label'); await titleBar(body,'Scan');
  const seg = await segmented(['Food','Date label'],'Date label'); body.appendChild(seg); fill(seg);
  const photo = AL('VERTICAL',{itemSpacing:6}); photo.primaryAxisAlignItems='CENTER'; photo.counterAxisAlignItems='CENTER'; photo.resize(361,200); photo.primaryAxisSizingMode='FIXED'; photo.cornerRadius=28; photo.fills=[{type:'SOLID',color:{r:0.98,g:0.95,b:0.86}}];
  for (const l of ['FRESH MILK 1L','MFD 10/10/2026','USE BY 21 OCT 2026']) { const t=figma.createText(); t.fontName={family:'Inter',style:'Medium'}; t.characters=l; t.fontSize= l.startsWith('USE')?26:16; t.fills=[{type:'SOLID',color:{r:0.1,g:0.1,b:0.1}}]; photo.appendChild(t); }
  const hl = figma.createRectangle(); hl.resize(300,40); hl.fills=[]; hl.strokes=[P('brand/primary')]; hl.strokeWeight=3; hl.cornerRadius=8; photo.appendChild(hl); hl.layoutPositioning='ABSOLUTE'; hl.x=30; hl.y=118;
  body.appendChild(photo); fill(photo);
  const res = card('VERTICAL',16,12); await res.setEffectStyleIdAsync(shadow.id); body.appendChild(res); fill(res);
  const rl = AL('HORIZONTAL',{itemSpacing:8}); rl.counterAxisAlignItems='CENTER'; rl.appendChild(icon('event_available',26,'brand/primary')); rl.appendChild(await txt('Best before 21 October 2026','Title 3','brand/primary')); res.appendChild(rl);
  res.appendChild(await txt('Expiry keyword found after the manufacture date, so FreshKeep picked the USE BY date.','Footnote','text/secondary',329));
  const b = variant(comps.btn,{Style:'Primary'}).createInstance(); setText(b,'Label','Add item with this date'); b.findOne(n=>n.name.startsWith('Icon')).characters='add'; res.appendChild(b); fill(b);
  const dg = AL('HORIZONTAL',{itemSpacing:6}); dg.counterAxisAlignItems='CENTER'; dg.appendChild(icon('chevron_right',18,'brand/primary')); dg.appendChild(await txt('Text we read','Subheadline','brand/primary')); res.appendChild(dg);
  tabBar(f,'Scan'); ids.push(f.id); }

// 7. Add item
{ const {f, body} = await screen('07 Add Item');
  const nav = AL('HORIZONTAL'); nav.primaryAxisAlignItems='SPACE_BETWEEN'; nav.counterAxisAlignItems='CENTER'; nav.paddingTop=8; body.appendChild(nav); fill(nav);
  nav.appendChild(await txt('Cancel','Body','brand/primary')); nav.appendChild(await txt('Add item','Headline')); nav.appendChild(await txt('Save','Headline','brand/primary'));
  const group = async (header, rows, footer) => { if (header) body.appendChild(await txt(header.toUpperCase(),'Footnote','text/secondary'));
    const g = AL('VERTICAL'); g.fills=[P('surface/card')]; g.cornerRadius=12; g.clipsContent=true; body.appendChild(g); fill(g);
    rows.forEach((r,i) => { r.paddingLeft=r.paddingRight=16; r.paddingTop=r.paddingBottom=11; g.appendChild(r); fill(r); if (i<rows.length-1) { const s=figma.createRectangle(); s.resize(300,1); s.fills=[P('separator')]; g.appendChild(s); fill(s);} });
    if (footer) body.appendChild(footer); };
  const lr = async (l, v, vc='text/secondary') => { const r = AL('HORIZONTAL'); r.primaryAxisAlignItems='SPACE_BETWEEN'; r.counterAxisAlignItems='CENTER'; r.appendChild(await txt(l,'Body')); if (v) r.appendChild(await txt(v,'Body',vc)); return r; };
  const ph = AL('HORIZONTAL',{itemSpacing:16}); ph.counterAxisAlignItems='CENTER';
  const tile = AL('HORIZONTAL'); tile.primaryAxisAlignItems='CENTER'; tile.counterAxisAlignItems='CENTER'; tile.resize(64,64); tile.primaryAxisSizingMode='FIXED'; tile.counterAxisSizingMode='FIXED'; tile.cornerRadius=16; tile.fills=[P('brand/primary',0.12)]; tile.appendChild(await txt('🍌','Title 1')); ph.appendChild(tile);
  const pl = AL('HORIZONTAL',{itemSpacing:6}); pl.counterAxisAlignItems='CENTER'; pl.appendChild(icon('image',20,'brand/primary')); pl.appendChild(await txt('Change photo','Body','brand/primary')); ph.appendChild(pl);
  await group(null,[ph]);
  const name = await lr('Banana');
  const seg = await segmented(['Fridge','Freezer','Pantry','Counter'],'Counter');
  const segRow = AL('HORIZONTAL'); segRow.appendChild(seg); fill(seg);
  await group('Food',[name, await lr('Category','Fruit  ›'), segRow, await lr('Quantity: 4','−  +','brand/primary')]);
  const est = AL('HORIZONTAL',{itemSpacing:6}); est.counterAxisAlignItems='CENTER'; est.appendChild(icon('auto_awesome',16,'brand/primary')); est.appendChild(await txt('Estimated 5 days on the counter','Footnote','text/secondary'));
  const ocr = AL('HORIZONTAL',{itemSpacing:6}); ocr.counterAxisAlignItems='CENTER'; ocr.appendChild(icon('document_scanner',20,'brand/primary')); ocr.appendChild(await txt('Read date from label photo','Body','brand/primary'));
  const dp = AL('HORIZONTAL'); dp.primaryAxisAlignItems='SPACE_BETWEEN'; dp.counterAxisAlignItems='CENTER'; dp.appendChild(await txt('Expires','Body')); const pill = AL('HORIZONTAL'); pill.fills=[P('surface/chip')]; pill.cornerRadius=8; pill.paddingLeft=pill.paddingRight=10; pill.paddingTop=pill.paddingBottom=5; pill.appendChild(await txt('19 Oct 2026','Body')); dp.appendChild(pill);
  const foot = AL('HORIZONTAL',{itemSpacing:6}); foot.appendChild(icon('lightbulb',16,'text/secondary')); foot.appendChild(await txt('Store on the counter and wrap the stems.','Footnote','text/secondary'));
  await group('Best before',[dp, est, ocr], foot);
  await group('Details',[await lr('Price (LKR)','30'), await lr('Notes','')]);
  ids.push(f.id); }

// 8. Insights
{ const {f, body} = await screen('08 Insights'); await titleBar(body,'Insights');
  const hero = AL('HORIZONTAL',{itemSpacing:16}); hero.counterAxisAlignItems='CENTER'; hero.paddingLeft=hero.paddingRight=hero.paddingTop=hero.paddingBottom=20; hero.cornerRadius=24;
  hero.fills=[{type:'GRADIENT_LINEAR',gradientTransform:[[0.7,0.7,0],[-0.7,0.7,0.5]],gradientStops:[{position:0,color:{r:0.17,g:0.68,b:0.4,a:1}},{position:1,color:{r:0.06,g:0.42,b:0.28,a:1}}]}];
  const rg = figma.createFrame(); rg.resize(90,90); rg.fills=[];
  const t1 = figma.createEllipse(); t1.resize(90,90); t1.arcData={startingAngle:0,endingAngle:2*Math.PI,innerRadius:0.76}; t1.fills=[{type:'SOLID',color:{r:1,g:1,b:1},opacity:0.25}]; rg.appendChild(t1);
  const t2 = figma.createEllipse(); t2.resize(90,90); t2.arcData={startingAngle:-Math.PI/2,endingAngle:-Math.PI/2+2*Math.PI*0.75,innerRadius:0.76}; t2.fills=[{type:'SOLID',color:{r:1,g:1,b:1}}]; rg.appendChild(t2);
  const pc = await txt('75%','Title 2','text/on-brand'); rg.appendChild(pc); pc.x=45-pc.width/2; pc.y=45-pc.height/2; hero.appendChild(rg);
  const hc = AL('VERTICAL',{itemSpacing:4}); hc.appendChild(await txt('Rescue rate','Headline','text/on-brand')); hc.appendChild(await txt('You ate 15 of 20 items before they expired.','Subheadline','text/on-brand',200)); hero.appendChild(hc);
  body.appendChild(hero); fill(hero);
  const grid = AL('HORIZONTAL',{itemSpacing:12}); grid.layoutWrap='WRAP'; grid.counterAxisSpacing=12; body.appendChild(grid); fill(grid);
  for (const [ic,v,t,tok] of [['payments','LKR 8,950','Money saved','brand/primary'],['verified','15','Items rescued','brand/primary'],['eco','9.4 kg','CO₂e avoided','freshness/fresh'],['local_fire_department','4 days','Zero-waste streak','brand/citrus']]) {
    const s = comps.stat.createInstance(); setText(s,'Value',v); setText(s,'Title',t); const g = s.findOne(n=>n.name.startsWith('Icon:')); g.characters=ic; g.fills=[P(tok)]; s.findOne(n=>n.type==='FRAME'&&n.name==='Icon').fills=[P(tok,0.14)]; grid.appendChild(s); s.resize(174.5, s.height); }
  const ch = card('VERTICAL',16,12); await ch.setEffectStyleIdAsync(shadow.id); body.appendChild(ch); fill(ch);
  ch.appendChild(await txt('Last 6 weeks','Headline'));
  const bars = AL('HORIZONTAL',{itemSpacing:22}); bars.counterAxisAlignItems='MAX'; bars.resize(320,120); bars.counterAxisSizingMode='FIXED';
  for (const [e,w] of [[3,1],[4,1],[2,1],[3,1],[4,0],[2,1]]) { const col = AL('VERTICAL',{itemSpacing:2}); col.counterAxisAlignItems='CENTER';
    const r1=figma.createRectangle(); r1.resize(28,w*18); r1.fills=[P('freshness/today')]; r1.topLeftRadius=r1.topRightRadius=4; if(w) col.appendChild(r1);
    const r2=figma.createRectangle(); r2.resize(28,e*22); r2.fills=[P('brand/primary')]; r2.cornerRadius=4; col.appendChild(r2); bars.appendChild(col); }
  ch.appendChild(bars);
  const leg = AL('HORIZONTAL',{itemSpacing:16}); for (const [c,l] of [['brand/primary','Eaten'],['freshness/today','Wasted']]) { const li=AL('HORIZONTAL',{itemSpacing:6}); li.counterAxisAlignItems='CENTER'; const d=figma.createEllipse(); d.resize(10,10); d.fills=[P(c)]; li.appendChild(d); li.appendChild(await txt(l,'Caption','text/secondary')); leg.appendChild(li);} ch.appendChild(leg);
  tabBar(f,'Insights'); ids.push(f.id); }

// 9. Recipe
{ const {f, body} = await screen('09 Recipe (Use it up)');
  const nav = AL('HORIZONTAL',{itemSpacing:2}); nav.counterAxisAlignItems='CENTER'; nav.appendChild(icon('chevron_left',26,'brand/primary')); nav.appendChild(await txt('Insights','Body','brand/primary')); body.appendChild(nav);
  const head = card('HORIZONTAL',16,16); head.counterAxisAlignItems='CENTER'; body.appendChild(head); fill(head);
  const em = await txt('🥤','Large Title'); em.fontSize=56; em.lineHeight={unit:'PIXELS',value:64}; head.appendChild(em);
  const hc = AL('VERTICAL',{itemSpacing:4}); hc.appendChild(await txt('Banana Smoothie','Title 2')); const tm = AL('HORIZONTAL',{itemSpacing:4}); tm.counterAxisAlignItems='CENTER'; tm.appendChild(icon('schedule',16,'text/secondary')); tm.appendChild(await txt('5 minutes','Subheadline','text/secondary')); hc.appendChild(tm); head.appendChild(hc);
  const list = async (h, items) => { body.appendChild(await txt(h.toUpperCase(),'Footnote','text/secondary')); const g = card('VERTICAL',16,12); body.appendChild(g); fill(g); for (const [ic,t,c] of items) { const r=AL('HORIZONTAL',{itemSpacing:10}); r.counterAxisAlignItems='MIN'; r.appendChild(icon(ic,22,c)); r.appendChild(await txt(t,'Body', c==='text/secondary'?'text/secondary':'text/primary',290)); g.appendChild(r);} };
  await list('You have',[['check_circle','🍌 Banana — expires today','brand/primary'],['check_circle','🥛 Milk — 1 day left','brand/primary']]);
  await list("You'll also need",[['shopping_cart','🥣 Yogurt','text/secondary']]);
  await list('Steps',[['check_circle','Peel and slice the bananas.','brand/primary'],['looks_two','Blend with milk and yogurt until smooth.','text/primary'],['looks_3','Serve cold or freeze as popsicles.','text/primary']]);
  tabBar(f,'Insights'); ids.push(f.id); }

// 10. Settings
{ const {f, body} = await screen('10 Settings'); await titleBar(body,'Settings');
  const toggle = (on=true) => { const t = figma.createFrame(); t.resize(51,31); t.cornerRadius=16; t.fills=[on?P('brand/primary'):P('separator')]; const k=figma.createEllipse(); k.resize(27,27); k.x=on?22:2; k.y=2; k.fills=[{type:'SOLID',color:{r:1,g:1,b:1}}]; t.appendChild(k); return t; };
  const grp = async (h, rows, foot) => { body.appendChild(await txt(h.toUpperCase(),'Footnote','text/secondary')); const g = AL('VERTICAL'); g.fills=[P('surface/card')]; g.cornerRadius=12; g.clipsContent=true; body.appendChild(g); fill(g);
    for (let i=0;i<rows.length;i++){ const [l,v] = rows[i]; const r = AL('HORIZONTAL'); r.primaryAxisAlignItems='SPACE_BETWEEN'; r.counterAxisAlignItems='CENTER'; r.paddingLeft=r.paddingRight=16; r.paddingTop=r.paddingBottom=11;
      r.appendChild(await txt(l,'Body', l.startsWith('Erase')?'freshness/expired': (v===null?'brand/primary':'text/primary'))); if (v==='toggle') r.appendChild(toggle()); else if (v) r.appendChild(await txt(v,'Body','text/secondary')); g.appendChild(r); fill(r);
      if (i<rows.length-1){ const s=figma.createRectangle(); s.resize(300,1); s.fills=[P('separator')]; g.appendChild(s); fill(s);} }
    if (foot) body.appendChild(await txt(foot,'Footnote','text/secondary',361)); };
  await grp('Notifications',[['Expiry reminders','toggle'],['Remind me 2 days before','−  +'],['Reminder time','9:00 AM']],'Reminders are scheduled on your device. No account needed.');
  await grp('Freshness',[['"Use soon" when 2 days left','−  +']]);
  const seg = await segmented(['System','Light','Dark'],'System'); body.appendChild(await txt('APPEARANCE','Footnote','text/secondary')); body.appendChild(seg); fill(seg);
  await grp('Data',[['Items tracked','32'],['Load sample pantry',null],['Erase all data',null]]);
  tabBar(f,'Settings'); ids.push(f.id); }
let maxX=0,maxY=0; for (const c of sec.children){maxX=Math.max(maxX,c.x+c.width);maxY=Math.max(maxY,c.y+c.height);} sec.resizeWithoutConstraints(maxX+80,maxY+80);
return {ids};
