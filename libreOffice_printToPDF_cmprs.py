import sys
import subprocess
from pathlib import Path
import shutil

def convert_docx_to_pdf_lossless(docx_path):
    docx = Path(docx_path).resolve()
    if not docx.exists():
        raise FileNotFoundError(f"Input file not found: {docx}")

    outdir = docx.parent
    pdf_path = docx.with_suffix(".pdf")

    soffice = r"C:\Program Files\LibreOffice\program\soffice.exe"

    filter_options = (
        'pdf:writer_pdf_Export:'
        '{"UseLosslessCompression":{"type":"boolean","value":"true"},'
        '"ReduceImageResolution":{"type":"boolean","value":"false"}}'
    )

    cmd = [
        soffice,
        "--headless",
        "--nologo",
        "--nolockcheck",
        "--norestore",
        "--convert-to", filter_options,
        "--outdir", str(outdir),
        str(docx),
    ]

    print("Running command:")
    print(" ".join(cmd))
    subprocess.run(cmd, check=True)

    if not pdf_path.exists():
        raise FileNotFoundError("Conversion finished, but PDF not found!")

    # Optional: lossless post-optimization with qpdf
    qpdf = shutil.which("qpdf")
    if qpdf:
        optimized = docx.with_name(docx.stem + "_opt.pdf")
        qcmd = [qpdf, "--stream-data=compress", "--object-streams=generate", "--recompress-flate",
                str(pdf_path), str(optimized)]
        print("Running qpdf optimization:")
        print(" ".join(qcmd))
        subprocess.run(qcmd, check=True)
        print(f"Created optimized PDF:\n  {optimized}")
        return optimized

    print(f"Created lossless PDF:\n  {pdf_path}")
    return pdf_path

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python libreOffice_printToPDF.py <path_to_docx>")
        sys.exit(1)

    convert_docx_to_pdf_lossless(sys.argv[1])
