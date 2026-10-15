// Shared helpers for generating the FreshKeep Word documents with docx-js.
const fs = require('fs');
const path = require('path');
const {
  Document, Packer, Paragraph, TextRun, HeadingLevel, AlignmentType, Table, TableRow, TableCell,
  WidthType, ShadingType, BorderStyle, ImageRun, PageBreak, Footer, Header, PageNumber,
  TableOfContents, LevelFormat, ExternalHyperlink, TabStopType, TabStopPosition,
} = require('docx');

const FONT = 'Times New Roman';
const GREEN = '0F6B47';
const ACCENT = '2BAE66';
const IMG = path.join(__dirname, '..', 'images');

/**
 * Document look. 'fresh' is the original branded style (A4, green headings, cover page,
 * header/footer). 'sample' copies the plain lab-report template the student supplied:
 * US Letter, 1" margins, Times New Roman 12 pt body, blue Word-default headings,
 * centred bold title block, no cover/header/footer, plain black-bordered tables.
 */
const ST = {
  name: 'fresh', headFont: FONT, pageW: 11906, pageH: 16838, margin: 1300, marginTB: 1200,
  h1: { size: 32, color: GREEN, before: 360, after: 180 },
  h2: { size: 28, color: GREEN, before: 260, after: 120 },
  h3: { size: 24, color: undefined, before: 200, after: 100 },
  body: { after: 140, line: 300, align: AlignmentType.JUSTIFIED },
  tableHeaderFill: GREEN, tableHeaderColor: 'FFFFFF', border: 'BFC9C2', captionColor: '5F6B64',
  bulletIndent: { left: 540, hanging: 270 }, codeShading: 'F2F5F1', headerFooter: true,
};
function useStyle(name) {
  if (name !== 'sample') return;
  Object.assign(ST, {
    name: 'sample', headFont: 'Calibri', pageW: 12240, pageH: 15840, margin: 1440, marginTB: 1440,
    h1: { size: 28, color: '365F91', before: 480, after: 0 },
    h2: { size: 26, color: '4F81BD', before: 200, after: 0 },
    h3: { size: 24, color: '4F81BD', before: 200, after: 0 },
    body: { after: 200, line: 276, align: AlignmentType.LEFT },
    tableHeaderFill: undefined, tableHeaderColor: undefined, border: '000000', captionColor: '595959',
    bulletIndent: { left: 360, hanging: 360 }, codeShading: undefined, headerFooter: false,
  });
}
const contentW = () => ST.pageW - ST.margin * 2;
const CONTENT_W = 11906 - 1300 * 2;

const run = (text, opts = {}) => new TextRun({ text, font: FONT, size: 24, ...opts });

/** Paragraph from a string; supports **bold** and `code` inline markup. */
function p(text, opts = {}) {
  const parts = [];
  const re = /(\*\*[^*]+\*\*|`[^`]+`)/g;
  let last = 0; let m;
  while ((m = re.exec(text))) {
    if (m.index > last) parts.push(run(text.slice(last, m.index), opts.run));
    const token = m[0];
    if (token.startsWith('**')) parts.push(run(token.slice(2, -2), { bold: true, ...opts.run }));
    else parts.push(new TextRun({ text: token.slice(1, -1), font: 'Consolas', size: 21, ...opts.run }));
    last = m.index + token.length;
  }
  if (last < text.length) parts.push(run(text.slice(last), opts.run));
  return new Paragraph({ children: parts, spacing: { after: ST.body.after, line: ST.body.line }, alignment: opts.align || ST.body.align, ...opts.para });
}

const heading = (level, st) => (text) => new Paragraph({ keepNext: true, heading: level, children: [new TextRun({ text, font: ST.headFont, size: st().size, bold: true, color: st().color })], spacing: { before: st().before, after: st().after } });
const h1 = heading(HeadingLevel.HEADING_1, () => ST.h1);
const h2 = heading(HeadingLevel.HEADING_2, () => ST.h2);
const h3 = heading(HeadingLevel.HEADING_3, () => ST.h3);

const bullet = (text, level = 0) => {
  const para = p(text, { para: { numbering: { reference: 'bullets', level }, spacing: { after: 80, line: 280 } }, align: AlignmentType.LEFT });
  return para;
};
const numbered = (text, ref = 'numbers') => p(text, { para: { numbering: { reference: ref, level: 0 }, spacing: { after: 80, line: 280 } }, align: AlignmentType.LEFT });

const pageBreak = () => new Paragraph({ children: [new PageBreak()] });

const cellBorders = () => { const b = { style: BorderStyle.SINGLE, size: 4, color: ST.border }; return { top: b, bottom: b, left: b, right: b }; };

/** Table with a styled header row. widths are relative weights. */
function table(headers, rows, weights) {
  const CONTENT_W = contentW();
  const borders = cellBorders();
  const w = weights || headers.map(() => 1);
  const total = w.reduce((a, b) => a + b, 0);
  const cols = w.map((x) => Math.floor((x / total) * CONTENT_W));
  cols[cols.length - 1] += CONTENT_W - cols.reduce((a, b) => a + b, 0);
  const cell = (text, i, header) => new TableCell({
    borders,
    width: { size: cols[i], type: WidthType.DXA },
    shading: header && ST.tableHeaderFill ? { fill: ST.tableHeaderFill, type: ShadingType.CLEAR, color: 'auto' } : undefined,
    margins: { top: 70, bottom: 70, left: 110, right: 110 },
    children: String(text).split('\n').map((line) => new Paragraph({
      children: inline(line, header ? { bold: true, color: ST.tableHeaderColor, size: 21 } : { size: 21 }),
      spacing: { after: 30 },
    })),
  });
  return new Table({
    width: { size: CONTENT_W, type: WidthType.DXA },
    columnWidths: cols,
    rows: [
      new TableRow({ tableHeader: true, children: headers.map((h, i) => cell(h, i, true)) }),
      ...rows.map((r) => new TableRow({ children: r.map((c, i) => cell(c, i, false)) })),
    ],
  });
}

function inline(text, opts) {
  const parts = [];
  const re = /(\*\*[^*]+\*\*|`[^`]+`)/g;
  let last = 0; let m;
  while ((m = re.exec(text))) {
    if (m.index > last) parts.push(run(text.slice(last, m.index), opts));
    const t = m[0];
    if (t.startsWith('**')) parts.push(run(t.slice(2, -2), { ...opts, bold: true }));
    else parts.push(new TextRun({ text: t.slice(1, -1), font: 'Consolas', size: 19 }));
    last = m.index + t.length;
  }
  if (last < text.length) parts.push(run(text.slice(last), opts));
  return parts;
}

/** Reads PNG dimensions from the IHDR chunk. */
function pngSize(buf) {
  return { w: buf.readUInt32BE(16), h: buf.readUInt32BE(20) };
}

/** Image scaled to a width in inches (aspect kept), with optional caption. */
function image(file, widthIn = 6.2, caption) {
  const full = path.isAbsolute(file) ? file : path.join(IMG, file);
  const data = fs.readFileSync(full);
  const { w, h } = pngSize(data);
  const width = Math.round(widthIn * 96);
  const height = Math.round((h / w) * width);
  const out = [new Paragraph({ alignment: AlignmentType.CENTER, spacing: { before: 120, after: caption ? 40 : 160 },
    children: [new ImageRun({ type: 'png', data, transformation: { width, height } })] })];
  if (caption) out.push(new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 200 }, children: [run(caption, { italics: true, size: 20, color: ST.captionColor })] }));
  return out;
}

/** Several images side by side in a borderless table. */
function imageRow(files, widthIn = 2.0, captions = []) {
  const CONTENT_W = contentW();
  const colW = Math.floor(CONTENT_W / files.length);
  const none = { style: BorderStyle.NONE, size: 0, color: 'FFFFFF' };
  return new Table({
    width: { size: CONTENT_W, type: WidthType.DXA },
    columnWidths: files.map(() => colW),
    rows: [new TableRow({ children: files.map((f, i) => {
      const data = fs.readFileSync(path.isAbsolute(f) ? f : path.join(IMG, f));
      const { w, h } = pngSize(data);
      const width = Math.round(widthIn * 96);
      return new TableCell({ width: { size: colW, type: WidthType.DXA }, borders: { top: none, bottom: none, left: none, right: none },
        children: [
          new Paragraph({ alignment: AlignmentType.CENTER, children: [new ImageRun({ type: 'png', data, transformation: { width, height: Math.round((h / w) * width) } })] }),
          ...(captions[i] ? [new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 120 }, children: [run(captions[i], { italics: true, size: 18, color: ST.captionColor })] })] : []),
        ] });
    }) })],
  });
}

function cover({ title, subtitle, docType, extra = [] }) {
  if (ST.name === 'sample') {
    // Same title block as the student's template: centred bold 16 pt, then bold labels.
    const label = (k, v) => new Paragraph({ spacing: { after: ST.body.after, line: ST.body.line }, children: [run(`${k}: `, { bold: true }), run(v)] });
    return [
      new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 200, line: 276 }, children: [
        run('SE4041 – Mobile Application Design and Development', { bold: true, size: 32 }),
        run(`Assignment 02 – ${title} ${docType}`, { bold: true, size: 32, break: 1 })] }),
      label('Student Name', 'Abisheak S'),
      label('Student ID', 'IT21244384'),
      label('GitHub Repository', 'https://github.com/IT21244384/SE4041-FreshKeep'),
      ...extra.map(([k, v]) => label(k, v)),
    ];
  }
  const lines = [
    new Paragraph({ alignment: AlignmentType.CENTER, spacing: { before: 600, after: 120 }, children: [run('SRI LANKA INSTITUTE OF INFORMATION TECHNOLOGY', { bold: true, size: 26 })] }),
    new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 80 }, children: [run('Faculty of Computing — BSc (Hons) in Information Technology', { size: 22 })] }),
    new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 400 }, children: [run('SE4041 — Mobile Application Design and Development', { size: 22 })] }),
    ...image('app-icon.png', 1.6),
    new Paragraph({ alignment: AlignmentType.CENTER, spacing: { before: 200, after: 120 }, children: [run(title, { bold: true, size: 56, color: GREEN })] }),
    new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 120 }, children: [run(subtitle, { italics: true, size: 28, color: '5F6B64' })] }),
    new Paragraph({ alignment: AlignmentType.CENTER, spacing: { before: 200, after: 600 }, children: [run(docType, { bold: true, size: 32 })] }),
  ];
  const details = [
    ['Student name', 'Abisheak S'],
    ['Student ID', 'IT21244384'],
    ['Assignment', 'Assignment 02 — Swift (Part A: iOS · Part B: visionOS)'],
    ['GitHub repository', 'github.com/IT21244384/SE4041-FreshKeep'],
    ['Submission date', '14 October 2026'],
    ...extra,
  ];
  lines.push(table(['Item', 'Details'], details, [1, 2.2]));
  lines.push(pageBreak());
  return lines;
}

function toc() {
  if (ST.name === 'sample') return [];
  return [
    new Paragraph({ children: [run('Table of Contents', { bold: true, size: 32, color: GREEN })], spacing: { after: 200 } }),
    new TableOfContents('Table of Contents', { hyperlink: true, headingStyleRange: '1-2' }),
    pageBreak(),
  ];
}

function build(file, children, headerTitle) {
  const doc = new Document({
    creator: 'Abisheak S (IT21244384)',
    title: headerTitle,
    features: { updateFields: true },
    styles: {
      default: { document: { run: { font: FONT, size: 24 }, paragraph: { spacing: { after: ST.body.after, line: ST.body.line } } } },
      paragraphStyles: [1, 2, 3].map((n) => { const h = ST[`h${n}`]; return { id: `Heading${n}`, name: `Heading ${n}`, basedOn: 'Normal', next: 'Normal', quickFormat: true,
        run: { size: h.size, bold: true, font: ST.headFont, color: h.color }, paragraph: { keepNext: true, keepLines: true, spacing: { before: h.before, after: h.after }, outlineLevel: n - 1 } }; }),
    },
    numbering: {
      config: [
        { reference: 'bullets', levels: [
          { level: 0, format: LevelFormat.BULLET, text: '•', alignment: AlignmentType.LEFT, style: { paragraph: { indent: ST.bulletIndent } } },
          { level: 1, format: LevelFormat.BULLET, text: '◦', alignment: AlignmentType.LEFT, style: { paragraph: { indent: { left: 1000, hanging: 270 } } } },
        ] },
        ...['numbers', 'numbers2', 'numbers3', 'numbers4', 'numbers5'].map((reference) => ({ reference, levels: [
          { level: 0, format: LevelFormat.DECIMAL, text: '%1.', alignment: AlignmentType.LEFT, style: { paragraph: { indent: { left: 540, hanging: 300 } } } },
        ] })),
      ],
    },
    sections: [{
      properties: { page: { size: { width: ST.pageW, height: ST.pageH }, margin: { top: ST.marginTB, bottom: ST.marginTB, left: ST.margin, right: ST.margin } }, titlePage: ST.headerFooter },
      ...(ST.headerFooter ? { headers: { default: new Header({ children: [new Paragraph({ alignment: AlignmentType.RIGHT, border: { bottom: { style: BorderStyle.SINGLE, size: 6, color: ACCENT, space: 4 } },
        children: [run(`FreshKeep — ${headerTitle}`, { size: 18, color: '5F6B64' })] })] }) },
      footers: { default: new Footer({ children: [new Paragraph({ tabStops: [{ type: TabStopType.RIGHT, position: contentW() }],
        children: [run('IT21244384 · SE4041 Assignment 02', { size: 18, color: '5F6B64' }), run('\tPage ', { size: 18, color: '5F6B64' }), new TextRun({ children: [PageNumber.CURRENT], font: FONT, size: 18, color: '5F6B64' })] })] }) } } : {}),
      children,
    }],
  });
  return Packer.toBuffer(doc).then((buf) => { fs.writeFileSync(file, buf); console.log('Wrote', file); });
}

/**
 * Minimal Markdown → docx converter for the repo's .md docs (headings, paragraphs,
 * bullets, numbered lists, pipe tables, fenced code, images). `shift` demotes headings.
 */
function markdown(file, { shift = 0, skipTitle = true } = {}) {
  const src = fs.readFileSync(file, 'utf8').replace(/\r/g, '');
  const lines = src.split('\n');
  const out = [];
  const heads = [h1, h2, h3, h3, h3];
  let i = 0;
  let firstHeading = true;
  let numRef = 'numbers3';
  while (i < lines.length) {
    const line = lines[i];
    if (!line.trim()) { i++; continue; }
    if (line.startsWith('```')) {
      const code = [];
      i++;
      while (i < lines.length && !lines[i].startsWith('```')) code.push(lines[i++]);
      i++;
      out.push(new Paragraph({ shading: ST.codeShading ? { fill: ST.codeShading, type: 'clear', color: 'auto' } : undefined, spacing: { after: 160, line: 240 },
        children: code.flatMap((c, k) => [new TextRun({ text: c || ' ', font: 'Consolas', size: 18, break: k ? 1 : 0 })]) }));
      continue;
    }
    const hm = line.match(/^(#{1,4})\s+(.*)/);
    if (hm) {
      if (firstHeading && skipTitle && hm[1].length === 1) { firstHeading = false; i++; continue; }
      firstHeading = false;
      out.push(heads[Math.min(hm[1].length - 1 + shift - 1, 4)](hm[2]));
      numRef = numRef === 'numbers3' ? 'numbers4' : 'numbers3';
      i++; continue;
    }
    const im = line.match(/^!\[[^\]]*\]\(([^)]+)\)/);
    if (im) { out.push(...image(path.join(path.dirname(file), im[1]), 6.0)); i++; continue; }
    if (line.startsWith('|')) {
      const rows = [];
      while (i < lines.length && lines[i].startsWith('|')) {
        if (!/^\|\s*-/.test(lines[i])) rows.push(lines[i].split('|').slice(1, -1).map((c) => c.trim()));
        i++;
      }
      out.push(table(rows[0], rows.slice(1)));
      out.push(new Paragraph({ children: [], spacing: { after: 120 } }));
      continue;
    }
    const bm = line.match(/^(\s*)[*-]\s+(.*)/);
    if (bm) {
      let text = bm[2];
      i++;
      while (i < lines.length && /^\s{2,}\S/.test(lines[i]) && !/^\s*[*-]\s/.test(lines[i])) text += ' ' + lines[i++].trim();
      out.push(bullet(text, bm[1].length >= 2 ? 1 : 0));
      continue;
    }
    const nm = line.match(/^\d+\.\s+(.*)/);
    if (nm) {
      let text = nm[1];
      i++;
      while (i < lines.length && /^\s{2,}\S/.test(lines[i])) text += ' ' + lines[i++].trim();
      out.push(numbered(text.replace(/\*([^*]+)\*/g, '$1'), numRef));
      continue;
    }
    let text = line.trim();
    i++;
    while (i < lines.length && lines[i].trim() && !/^(#|\||[*-]\s|\d+\.\s|```|!\[)/.test(lines[i].trim())) text += ' ' + lines[i++].trim();
    out.push(p(text.replace(/^>\s*/, '').replace(/\[([^\]]+)\]\([^)]+\)/g, '$1').replace(/(^|\s)\*([^*\s][^*]*)\*/g, '$1$2')));
  }
  return out;
}

module.exports = {
  markdown, useStyle, ST, p, h1, h2, h3, bullet, numbered, table, image, imageRow, cover, toc, build, pageBreak, run, CONTENT_W, IMG, Paragraph, TextRun, AlignmentType };
