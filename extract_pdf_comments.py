from pathlib import Path
import argparse
import fitz  # pip install pymupdf


def _clean_text(text):
    """Normalize whitespace but keep paragraph-like line breaks readable."""
    lines = [" ".join(line.split()) for line in text.splitlines()]
    lines = [line for line in lines if line]
    return "\n".join(lines).strip()


def _text_from_rect(page, rect):
    """Extract text from a rectangle, with a small fallback for difficult PDFs."""
    text = page.get_textbox(rect)
    text = _clean_text(text)
    if text:
        return text

    # Fallback: collect words whose bounding boxes intersect the rectangle.
    words = page.get_text("words")
    selected = []
    for word in words:
        wrect = fitz.Rect(word[:4])
        if rect.intersects(wrect):
            selected.append(word)

    # Sort by block, line, word number where available.
    selected.sort(key=lambda w: (w[5], w[6], w[7], w[0]))
    return " ".join(w[4] for w in selected).strip()


def extract_annotated_text(page, annot):
    """
    Return the manuscript text covered by a markup annotation.

    For highlight / underline / strikeout / squiggly annotations, PyMuPDF usually
    stores the selected text as quadrilaterals in annot.vertices. We extract text
    quad-by-quad to avoid pulling in unrelated text from the full annotation box.
    """
    vertices = getattr(annot, "vertices", None)

    if vertices and len(vertices) >= 4:
        pieces = []
        seen = set()

        # Markup annotations store vertices in groups of 4 points per quad.
        for i in range(0, len(vertices), 4):
            quad_points = vertices[i:i + 4]
            if len(quad_points) < 4:
                continue

            quad = fitz.Quad(quad_points)
            rect = quad.rect
            text = _text_from_rect(page, rect)
            text = _clean_text(text)

            if text and text not in seen:
                pieces.append(text)
                seen.add(text)

        return _clean_text("\n".join(pieces))

    # Fallback for annotations without vertices. This may be less precise because
    # annot.rect can include more than the selected text.
    return _clean_text(_text_from_rect(page, annot.rect))


def extract_pdf_comments(pdf_file):
    pdf_path = Path(pdf_file)

    if not pdf_path.exists():
        raise FileNotFoundError(f"File not found: {pdf_path}")

    out_path = pdf_path.with_name(pdf_path.stem + "_comments_with_highlighted_text.txt")

    doc = fitz.open(pdf_path)
    comments = []

    for page_number, page in enumerate(doc, start=1):
        annot = page.first_annot

        while annot:
            info = annot.info
            comment_text = info.get("content", "").strip()
            author = info.get("title", "").strip()
            annot_type = annot.type[1]

            # Extract manuscript text covered by the annotation. This works best
            # for Highlight, Underline, StrikeOut, and Squiggly annotations.
            annotated_text = extract_annotated_text(page, annot)

            # Keep annotations if they contain either a written comment or selected text.
            if comment_text or annotated_text:
                header = f"Page {page_number} | {annot_type}"
                if author:
                    header += f" | {author}"

                entry = [header, "=" * len(header)]

                if annotated_text:
                    entry.append("Highlighted text:")
                    entry.append(annotated_text)
                    entry.append("")

                if comment_text:
                    entry.append("Comment:")
                    entry.append(comment_text)
                    entry.append("")

                comments.append("\n".join(entry))

            annot = annot.next

    out_path.write_text("\n".join(comments), encoding="utf-8")

    print(f"Extracted {len(comments)} annotations with comments and/or highlighted text.")
    print(f"Saved to: {out_path}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Extract PDF annotation comments and highlighted manuscript text to a text file."
    )
    parser.add_argument(
        "pdf_file",
        help="Path to the PDF file, e.g. NEURON-D-26-00640_reviewer_SM.pdf"
    )

    args = parser.parse_args()
    extract_pdf_comments(args.pdf_file)
