"""Renders PDF pages to PNG previews: python tools/pdf_pages.py file.pdf outdir [zoom]"""
import os
import sys
import fitz  # PyMuPDF

pdf, out = sys.argv[1], sys.argv[2]
zoom = float(sys.argv[3]) if len(sys.argv) > 3 else 0.8
os.makedirs(out, exist_ok=True)
doc = fitz.open(pdf)
for i, page in enumerate(doc):
    page.get_pixmap(matrix=fitz.Matrix(zoom, zoom)).save(os.path.join(out, f"page-{i + 1:02d}.png"))
print(f"{len(doc)} pages")
