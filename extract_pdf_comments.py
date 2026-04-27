from pathlib import Path
import argparse
import fitz  # pip install pymupdf

def extract_pdf_comments(pdf_file):
    pdf_path = Path(pdf_file)

    if not pdf_path.exists():
        raise FileNotFoundError(f"File not found: {pdf_path}")

    out_path = pdf_path.with_name(pdf_path.stem + "_comments.txt")

    doc = fitz.open(pdf_path)
    comments = []

    for page_number, page in enumerate(doc, start=1):
        annot = page.first_annot

        while annot:
            info = annot.info
            text = info.get("content", "").strip()
            author = info.get("title", "").strip()
            annot_type = annot.type[1]

            if text:
                header = f"Page {page_number} | {annot_type}"
                if author:
                    header += f" | {author}"

                comments.append(f"{header}\n{'=' * len(header)}\n{text}\n")

            annot = annot.next

    out_path.write_text("\n".join(comments), encoding="utf-8")

    print(f"Extracted {len(comments)} comments.")
    print(f"Saved to: {out_path}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Extract PDF annotation comments to a text file."
    )
    parser.add_argument(
        "pdf_file",
        help="Path to the PDF file, e.g. NEURON-D-26-00640_reviewer_SM.pdf"
    )

    args = parser.parse_args()
    extract_pdf_comments(args.pdf_file)