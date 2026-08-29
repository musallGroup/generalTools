"""
Convert a .docx to PDF with Word's exact layout AND lossless images.

Problem: Word's ExportAsFixedFormat re-encodes embedded images as JPEG
(even at OptimizeFor=0), producing visible compression artifacts. LibreOffice
can produce lossless images but often mis-renders headers/pagination.

Solution: Use Word to produce the PDF (perfect layout), then replace any
JPEG-encoded image objects in the PDF with the original lossless bytes from
word/media/ inside the .docx. Image position and size on the page are
preserved by pymupdf's replace_image, so the layout is unchanged.

Prereqs:
  - Word installed (COM automation) — you must run this yourself in a terminal
    if invoked from Claude Code, since RPC from a non-interactive session fails.
  - Python packages: pymupdf, pillow

Usage:
  python docx_to_lossless_pdf.py <path\to\file.docx> [<output.pdf>]

If output path omitted, writes alongside the docx as <stem>.pdf, overwriting.
"""
from __future__ import annotations
import sys, os, zipfile, tempfile, shutil, hashlib
from pathlib import Path
from io import BytesIO

import pymupdf as fitz
from PIL import Image


def word_export_pdf(docx_path: Path, pdf_path: Path) -> None:
    """Drive Word via COM to export to PDF at print quality."""
    import win32com.client  # type: ignore
    word = win32com.client.DispatchEx("Word.Application")
    word.Visible = False
    word.DisplayAlerts = 0
    try:
        doc = word.Documents.Open(str(docx_path), ReadOnly=True, AddToRecentFiles=False)
        # ExportFormat=17 -> wdExportFormatPDF
        # OptimizeFor=0   -> wdExportOptimizeForPrint (higher quality than screen)
        # CreateBookmarks=0, DocStructureTags=True by default
        doc.ExportAsFixedFormat(
            OutputFileName=str(pdf_path),
            ExportFormat=17,
            OpenAfterExport=False,
            OptimizeFor=0,
            Range=0,          # wdExportAllDocument
            Item=0,            # wdExportDocumentContent
            IncludeDocProps=True,
            KeepIRM=True,
            CreateBookmarks=0,
            DocStructureTags=True,
            BitmapMissingFonts=True,
            UseISO19005_1=False,
        )
        doc.Close(SaveChanges=False)
    finally:
        word.Quit()


def load_docx_media(docx_path: Path) -> dict[str, bytes]:
    """Return dict of {basename: raw bytes} for every image in word/media/."""
    media: dict[str, bytes] = {}
    with zipfile.ZipFile(docx_path) as z:
        for name in z.namelist():
            if name.startswith("word/media/"):
                media[Path(name).name] = z.read(name)
    return media


def index_media_by_size(media: dict[str, bytes]) -> dict[tuple[int, int], list[tuple[str, bytes]]]:
    """Group media by (width, height) so we can look up sources by original dimensions."""
    by_size: dict[tuple[int, int], list[tuple[str, bytes]]] = {}
    for name, data in media.items():
        try:
            with Image.open(BytesIO(data)) as im:
                size = im.size
        except Exception:
            continue
        by_size.setdefault(size, []).append((name, data))
    return by_size


def replace_jpegs_with_originals(pdf_path: Path, docx_path: Path) -> int:
    """
    Find every JPEG-encoded image in the PDF and, if a source image in the .docx
    has the same aspect ratio (Word may downsample so exact-size match is not
    guaranteed), replace it with the original bytes. Returns count replaced.
    """
    media = load_docx_media(docx_path)
    if not media:
        print("[info] no images in word/media/, nothing to replace")
        return 0
    by_size = index_media_by_size(media)

    # Build lookup by aspect ratio. Use 2-decimal rounding for tolerance —
    # Word downsamples images so the PDF JPEG dimensions can differ slightly
    # from the source, shifting the 3rd decimal of the ratio.
    by_ratio: dict[float, list[tuple[str, bytes, tuple[int, int]]]] = {}
    for (w, h), entries in by_size.items():
        r = round(w / h, 2)
        for name, data in entries:
            by_ratio.setdefault(r, []).append((name, data, (w, h)))

    doc = fitz.open(pdf_path)
    replaced = 0
    try:
        for pno, page in enumerate(doc):
            for img in list(page.get_images(full=True)):
                xref = img[0]
                info = doc.extract_image(xref)
                if info["ext"] != "jpeg":
                    continue
                pw, ph = info["width"], info["height"]
                ratio = round(pw / ph, 2)
                candidates = by_ratio.get(ratio, [])
                # Prefer the largest candidate (most likely source)
                candidates.sort(key=lambda t: t[2][0] * t[2][1], reverse=True)
                if not candidates:
                    print(f"[warn] page {pno+1}: JPEG {pw}x{ph} has no aspect match in docx media; skipping")
                    continue
                name, data, (sw, sh) = candidates[0]
                # Write to a temp file because replace_image wants a filename or stream
                with tempfile.NamedTemporaryFile(suffix=Path(name).suffix, delete=False) as tf:
                    tf.write(data)
                    tmp_name = tf.name
                try:
                    page.replace_image(xref, filename=tmp_name)
                finally:
                    try:
                        os.unlink(tmp_name)
                    except OSError:
                        pass
                print(f"[ok]   page {pno+1}: replaced JPEG {pw}x{ph} with {name} ({sw}x{sh})")
                replaced += 1

        tmp_out = pdf_path.with_suffix(pdf_path.suffix + ".tmp")
        doc.save(tmp_out, garbage=4, deflate=True, clean=True)
    finally:
        doc.close()
    os.replace(tmp_out, pdf_path)
    return replaced


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print(__doc__)
        return 2
    docx = Path(argv[1]).resolve()
    if not docx.exists():
        print(f"not found: {docx}")
        return 1
    out = Path(argv[2]).resolve() if len(argv) > 2 else docx.with_suffix(".pdf")
    print(f"[step] Word export: {docx.name} -> {out.name}")
    word_export_pdf(docx, out)
    print(f"[step] Replace JPEGs with lossless source images ...")
    n = replace_jpegs_with_originals(out, docx)
    print(f"[done] {out}  ({n} images replaced, {out.stat().st_size} bytes)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
