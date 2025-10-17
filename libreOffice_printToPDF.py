import sys
import subprocess
from pathlib import Path

def convert_docx_to_pdf_lossless(docx_path):
    """
    Convert a DOCX file to PDF using LibreOffice without compressing or downsampling images.
    The resulting PDF keeps full image resolution (lossless).
    """
    docx = Path(docx_path).resolve()
    if not docx.exists():
        raise FileNotFoundError(f"Input file not found: {docx}")

    outdir = docx.parent
    pdf_path = docx.with_suffix(".pdf")

    # LibreOffice executable path — adjust if needed
    soffice = r"C:\Program Files\LibreOffice\program\soffice.exe"

    # PDF export filter options for lossless images
    filter_options = (
        'pdf:writer_pdf_Export:'
        '{"UseLosslessCompression":{"type":"boolean","value":"true"},'
        '"Quality":{"type":"long","value":"100"},'
        '"ReduceImageResolution":{"type":"boolean","value":"false"}}'
    )

    cmd = [
        soffice,
        "--headless",
        "--convert-to", filter_options,
        "--outdir", str(outdir),
        str(docx)
    ]

    print("Running command:")
    print(" ".join(cmd))

    subprocess.run(cmd, check=True)

    if pdf_path.exists():
        print(f"Created lossless PDF:\n  {pdf_path}")
    else:
        raise FileNotFoundError("Conversion finished, but PDF not found!")

    return pdf_path


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python convert_docx_to_pdf_lossless.py <path_to_docx>")
        sys.exit(1)

    input_path = sys.argv[1]
    convert_docx_to_pdf_lossless(input_path)
