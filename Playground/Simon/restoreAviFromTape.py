#!/usr/bin/env python3

"""
restoreAviFromTape.py

Scan a TAPE_TRANSFER subfolder for *.avi files and restore them
to their original source locations if missing.

Logic:
- Assumes structure like:
    O:\Massive Data Imaging\TAPE_TRANSFER\RemainingPath\file.avi

- Restores to:
    O:\Massive Data Imaging\RemainingPath\file.avi

- Only copies if the source file does NOT already exist.
- Does not overwrite.
"""

import shutil
import argparse
from pathlib import Path, PureWindowsPath


def compute_source_from_tape(tape_file: Path) -> Path:
    """
    Remove the 'TAPE_TRANSFER' component from the path.
    """
    pw = PureWindowsPath(str(tape_file))
    parts = list(pw.parts)

    if "TAPE_TRANSFER" not in [p.upper() for p in parts]:
        raise ValueError(f"Path does not contain TAPE_TRANSFER: {tape_file}")

    # Find index (case-insensitive)
    idx = next(i for i, p in enumerate(parts) if p.upper() == "TAPE_TRANSFER")

    # Remove that element
    new_parts = parts[:idx] + parts[idx+1:]

    return Path(str(PureWindowsPath(*new_parts)))


def restore_avi(tape_root: Path, dry_run: bool = False):
    restored = 0
    skipped = 0

    for avi_file in tape_root.rglob("*.avi"):
        try:
            src_path = compute_source_from_tape(avi_file)
        except ValueError:
            continue

        if src_path.exists():
            print(f"[SKIP] Already exists: {src_path}")
            skipped += 1
            continue

        print(f"[RESTORE] {avi_file} -> {src_path}")

        if not dry_run:
            src_path.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(avi_file, src_path)

        restored += 1

    print("-" * 80)
    print(f"Done. Restored: {restored} | Skipped (already existed): {skipped}")


def main():
    ap = argparse.ArgumentParser(description="Restore missing *.avi files from TAPE_TRANSFER to original location.")
    ap.add_argument("tape_folder", help="Path to TAPE_TRANSFER subfolder.")
    ap.add_argument("--dry-run", action="store_true", help="Show what would be restored without copying.")

    args = ap.parse_args()

    tape_root = Path(args.tape_folder)

    if not tape_root.exists():
        print(f"[ERROR] Folder does not exist: {tape_root}")
        return 1

    restore_avi(tape_root, dry_run=args.dry_run)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
