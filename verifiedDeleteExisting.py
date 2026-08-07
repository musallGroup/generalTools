#!/usr/bin/env python3

"""
verifiedDeleteExisting.py

Scoped companion to the serverTransfer.py two-pass SafeMove pattern, for when
Pass 1 (copy) got interrupted partway through (e.g. the source ran out of disk
space mid-job). Walks the DESTINATION tree only - since a file only exists
there if it was already fully copied - and for each one, hash-verifies it
against the matching SOURCE file before deleting the source. Source files that
were never copied simply aren't in the destination tree, so they're never
enumerated or touched, unlike re-running serverTransfer.py with --maxSize 0
against the whole source tree (which would fall back to an unverified
shutil.move for anything not yet copied).

Reuses serverTransfer.py's own partial_hash_match(), so the verification is
identical to the "MOVE-category + dst exists" cleanup path already built into
serverTransfer.py/tapeTransfer.py.

Default is DRY RUN. Pass --delete to actually remove verified-matching source
files.

Usage
-----
python verifiedDeleteExisting.py "\\naskampa.kampa-10g\lts\TAPE_TRANSFER\BpodBehavior" "\\naskampa.kampa-10g\data\TAPE_TRANSFER\BpodBehavior"
python verifiedDeleteExisting.py "\\naskampa.kampa-10g\lts\TAPE_TRANSFER\BpodBehavior" "\\naskampa.kampa-10g\data\TAPE_TRANSFER\BpodBehavior" --delete
"""

import argparse
import os
from pathlib import Path

from serverTransfer import (
    partial_hash_match,
    DEFAULT_SAMPLE_BLOCKS,
    DEFAULT_SAMPLE_BLOCK_KB,
)


def main() -> None:
    ap = argparse.ArgumentParser(
        description="Verified-delete source files that already have a matching, fully-copied destination copy."
    )
    ap.add_argument("source_root", help="Original source root (e.g. LTS TAPE_TRANSFER folder).")
    ap.add_argument("dest_root", help="Destination root that was partially copied to (e.g. DATA TAPE_TRANSFER folder).")
    ap.add_argument("--delete", action="store_true", help="Actually delete verified source files (default: dry-run).")
    ap.add_argument("--sample-blocks", type=int, default=DEFAULT_SAMPLE_BLOCKS)
    ap.add_argument("--sample-block-kb", type=int, default=DEFAULT_SAMPLE_BLOCK_KB)
    args = ap.parse_args()

    source_root = Path(args.source_root)
    dest_root = Path(args.dest_root)
    block_size = args.sample_block_kb * 1024

    deleted = mismatched = missing_source = errors = 0
    freed_bytes = 0

    print(f"Mode: {'LIVE' if args.delete else 'DRY RUN'}")
    print(f"Source root: {source_root}")
    print(f"Dest root:   {dest_root}")
    print("-" * 100)

    for root, _dirs, files in os.walk(dest_root):
        root_path = Path(root)
        rel_dir = root_path.relative_to(dest_root)
        for fname in files:
            dst_file = root_path / fname
            src_file = source_root / rel_dir / fname

            if not src_file.exists():
                print(f"[SKIP] No source file (already gone): {src_file}")
                missing_source += 1
                continue

            rel_path_posix = str((rel_dir / fname).as_posix())
            try:
                ok = partial_hash_match(
                    src_file, dst_file, rel_path_posix,
                    blocks=args.sample_blocks, block_size=block_size,
                )
            except Exception as e:
                print(f"[ERROR] Hash compare failed: {src_file} vs {dst_file} ({e})")
                errors += 1
                continue

            if not ok:
                print(f"[MISMATCH] Kept (does NOT match dst): {src_file}")
                mismatched += 1
                continue

            size = src_file.stat().st_size
            if args.delete:
                try:
                    src_file.unlink()
                    print(f"[DELETED] {src_file} ({size / 1024**2:.1f} MB)")
                except Exception as e:
                    print(f"[ERROR] Cannot delete: {src_file} ({e})")
                    errors += 1
                    continue
            else:
                print(f"[DRY-RUN] Would delete verified source: {src_file} ({size / 1024**2:.1f} MB)")

            deleted += 1
            freed_bytes += size

    print("-" * 100)
    verb = "Deleted" if args.delete else "Would delete"
    print(
        f"Done. {verb}: {deleted} files ({freed_bytes / 1024**3:.2f} GB) | "
        f"Mismatched(kept): {mismatched} | Missing source: {missing_source} | Errors: {errors}"
    )


if __name__ == "__main__":
    main()
