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
const PAGE_W = 11906; // A4 in DXA
const MARGIN = 1300;
const CONTENT_W = PAGE_W - MARGIN * 2;
const IMG = path.join(__dirname, '..', 'images');

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
  return new Paragraph({ children: parts, spacing: { after: 140, line: 300 }, alignment: opts.align || AlignmentType.JUSTIFIED, ...opts.para });
}

const h1 = (text) => new Paragraph({ keepNext: true, heading: HeadingLevel.HEADING_1, children: [new TextRun({ text, font: FONT, size: 32, bold: true, color: GREEN })], spacing: { before: 360, after: 180 }, pageBreakBefore: false });
const h2 = (text) => new Paragraph({ keepNext: true, heading: HeadingLevel.HEADING_2, children: [new TextRun({ text, font: FONT, size: 28, bold: true, color: GREEN })], spacing: { before: 260, after: 120 } });
const h3 = (text) => new Paragraph({ keepNext: true, heading: HeadingLevel.HEADING_3, children: [new TextRun({ text, font: FONT, size: 24, bold: true })], spacing: { before: 200, after: 100 } });

const bullet = (text, level = 0) => {
  const para = p(text, { para: { numbering: { reference: 'bullets', level }, spacing: { after: 80, line: 280 } }, align: AlignmentType.LEFT });
  return para;
};
const numbered = (text, ref = 'numbers') => p(text, { para: { numbering: { reference: ref, level: 0 }, spacing: { after: 80, line: 280 } }, align: AlignmentType.LEFT });

const pageBreak = () => new Paragraph({ children: [new PageBreak()] });

const border = { style: BorderStyle.SINGLE, size: 4, color: 'BFC9C2' };
const borders = { top: border, bottom: border, left: border, right: border };

/** Table with a green header row. widths are relative weights. */
function table(headers, rows, weights) {
  const w = weights || headers.map(() => 1);
  const total = w.reduce((a, b) => a + b, 0);
  const cols = w.map((x) => Math.floor((x / total) * CONTENT_W));
  cols[cols.length - 1] += CONTENT_W - cols.reduce((a, b) => a + b, 0);
  const cell = (text, i, header) => new TableCell({
    borders,
    width: { size: cols[i], type: WidthType.DXA },
    shading: header ? { fill: GREEN, type: ShadingType.CLEAR, color: 'auto' } : undefined,
    margins: { top: 70, bottom: 70, left: 110, right: 110 },
    children: String(text).split('\n').map((line) => new Paragraph({
      children: inline(line, header ? { bold: true, color: 'FFFFFF', size: 21 } : { size: 21 }),
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
  if (caption) out.push(new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 200 }, children: [run(caption, { italics: true, size: 20, color: '5F6B64' })] }));
  return out;
}

/** Several images side by side in a borderless table. */
function imageRow(files, widthIn = 2.0, captions = []) {
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
          ...(captions[i] ? [new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 120 }, children: [run(captions[i], { italics: true, size: 18, color: '5F6B64' })] })] : []),
        ] });
    }) })],
  });
}

function cover({ title, subtitle, docType, extra = [] }) {
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
      default: { document: { run: { font: FONT, size: 24 } } },
      paragraphStyles: [
        { id: 'Heading1', name: 'Heading 1', basedOn: 'Normal', next: 'Normal', quickFormat: true, run: { size: 32, bold: true, font: FONT, color: GREEN }, paragraph: { spacing: { before: 360, after: 180 }, outlineLevel: 0 } },
        { id: 'Heading2', name: 'Heading 2', basedOn: 'Normal', next: 'Normal', quickFormat: true, run: { size: 28, bold: true, font: FONT, color: GREEN }, paragraph: { spacing: { before: 260, after: 120 }, outlineLevel: 1 } },
        { id: 'Heading3', name: 'Heading 3', basedOn: 'Normal', next: 'Normal', quickFormat: true, run: { size: 24, bold: true, font: FONT }, paragraph: { spacing: { before: 200, after: 100 }, outlineLevel: 2 } },
      ],
    },
    numbering: {
      config: [
        { reference: 'bullets', levels: [
          { level: 0, format: LevelFormat.BULLET, text: '•', alignment: AlignmentType.LEFT, style: { paragraph: { indent: { left: 540, hanging: 270 } } } },
          { level: 1, format: LevelFormat.BULLET, text: '◦', alignment: AlignmentType.LEFT, style: { paragraph: { indent: { left: 1000, hanging: 270 } } } },
        ] },
        ...['numbers', 'numbers2', 'numbers3', 'numbers4', 'numbers5'].map((reference) => ({ reference, levels: [
          { level: 0, format: LevelFormat.DECIMAL, text: '%1.', alignment: AlignmentType.LEFT, style: { paragraph: { indent: { left: 540, hanging: 300 } } } },
        ] })),
      ],
    },
    sections: [{
      properties: { page: { size: { width: PAGE_W, height: 16838 }, margin: { top: 1200, bottom: 1200, left: MARGIN, right: MARGIN } }, titlePage: true },
      headers: { default: new Header({ children: [new Paragraph({ alignment: AlignmentType.RIGHT, border: { bottom: { style: BorderStyle.SINGLE, size: 6, color: ACCENT, space: 4 } },
        children: [run(`FreshKeep — ${headerTitle}`, { size: 18, color: '5F6B64' })] })] }) },
      footers: { default: new Footer({ children: [new Paragraph({ tabStops: [{ type: TabStopType.RIGHT, position: CONTENT_W }],
        children: [run('IT21244384 · SE4041 Assignment 02', { size: 18, color: '5F6B64' }), run('\tPage ', { size: 18, color: '5F6B64' }), new TextRun({ children: [PageNumber.CURRENT], font: FONT, size: 18, color: '5F6B64' })] })] }) },
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
      out.push(new Paragraph({ shading: { fill: 'F2F5F1', type: 'clear', color: 'auto' }, spacing: { after: 160 },
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
  markdown, p, h1, h2, h3, bullet, numbered, table, image, imageRow, cover, toc, build, pageBreak, run, CONTENT_W, IMG, Paragraph, TextRun, AlignmentType };
