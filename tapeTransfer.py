#!/usr/bin/env python3

"""
Created on Mon Jan 19 23:00:49 2026
@author: Simon

tapeTransfer.py

Purpose
-------
Stage data for tape transfer by mirroring a source directory tree into a derived target directory tree,
with rules for where to insert "TAPE_TRANSFER" into the path. By default, the script COPIES files;
it MOVES only large files (default threshold 10 GB) or files matching explicit "move" criteria.

This is designed for Windows paths, but will also accept UNC paths (\\server\share\...).

Path mapping rules
------------------
1) If the source path starts with:
      O:\Massive Data Imaging\RemainingPath
   then the target becomes:
      O:\Massive Data Imaging\TAPE_TRANSFER\RemainingPath

2) Otherwise, insert TAPE_TRANSFER as early as possible, right after the drive/share root:
      D:\foo\bar           -> D:\TAPE_TRANSFER\foo\bar
      \\srv\share\foo\bar  -> \\srv\share\TAPE_TRANSFER\foo\bar

Transfer rules
--------------
Default: COPY everything.

MOVE a file if ANY of the following are true:
- file size > --maxSize (GB)        [default: 10 GB]
- file extension matches --move-ext (e.g. .bin .dat .tif)
- filename contains --move-keyword  (case-insensitive substring match)

Existing destination behavior
-----------------------------
If destination file already exists:

- If --overwrite is used:
    Destination file is deleted and the script proceeds to copy/move anew.

- If --overwrite is NOT used:
    * COPY-category files:
        - Skip if size+mtime match (within a small tolerance).
        - Otherwise skip (mismatch), leaving both untouched.

    * MOVE-category files:
        - If destination exists, we do NOT move again.
        - Instead, we DELETE the SOURCE file ONLY if we can verify destination == source via:
            (1) same file size AND
            (2) deterministic partial-hash match (default ~1 MB sampled across the file)
        - If verification fails, we skip and keep the source (safety).

Why partial-hash?
----------------
Full hashing of huge files is often too slow (reads all bytes). Partial hashing reads small blocks
spread across the file (default: 16 blocks x 64 KB = ~1 MB), providing high confidence without the
I/O cost of hashing entire 10–200+ GB files. This is meant as a safety check before deleting sources.

Logging (default: enabled)
--------------------------
By default, the script writes a transfer log to BOTH:
- <source_root>\transferLog_YYYYMMDD_HHMMSS.log
- <target_root>\transferLog_YYYYMMDD_HHMMSS.log

The same log lines go to console AND both files.

Dry-run notes:
- --dry-run prints what would happen without copying/moving/deleting.
- It will still write the SOURCE log (source exists).
- It writes the TARGET log only if the target folder already exists (dry-run does not create it).

Examples (PowerShell)
---------------------
1) Basic:
   python tapeTransfer.py "O:\Massive Data Imaging\Proj\Session1"

2) Dry run:
   python tapeTransfer.py "O:\Massive Data Imaging\Proj\Session1" --dry-run

3) Force move some file types / keywords:
   python tapeTransfer.py "D:\data\run1" --move-ext .tif .tiff .bin --move-keyword raw video

4) Override maxSize (GB):
   python tapeTransfer.py "D:\data\run1" --maxSize 25

5) Overwrite existing target files:
   python tapeTransfer.py "D:\data\run1" --overwrite
   
"""

from __future__ import annotations

import argparse
import hashlib
import os
import random
import shutil
from datetime import datetime
from pathlib import PureWindowsPath, Path
from typing import Iterable, Optional, Tuple


# Default partial-hash sampling (~1 MB total)
DEFAULT_SAMPLE_BLOCKS = 16
DEFAULT_SAMPLE_BLOCK_KB = 64  # 16 * 64KB = 1024KB ~ 1MB


# ----------------------------
# Path mapping
# ----------------------------
def compute_target_path(source: str) -> PureWindowsPath:
    """
    Compute the derived target path by inserting "TAPE_TRANSFER" per the rules.
    PureWindowsPath is used so Windows path semantics apply even if run elsewhere.
    """
    p = PureWindowsPath(source)
    parts = list(p.parts)
    if not parts:
        raise ValueError("Empty source path.")

    # Rule 1: O:\Massive Data Imaging\...
    if len(parts) >= 2 and parts[0].lower() == "o:\\" and parts[1].lower() == "massive data imaging":
        return PureWindowsPath(parts[0], parts[1], "TAPE_TRANSFER", *parts[2:])

    # Rule 2: insert right after the root (drive root or UNC share root)
    return PureWindowsPath(parts[0], "TAPE_TRANSFER", *parts[1:])


def path_contains_tape_transfer(p: PureWindowsPath) -> bool:
    """Safety: detect if source already contains TAPE_TRANSFER."""
    return any(part.lower() == "tape_transfer" for part in p.parts)


# ----------------------------
# CLI parsing helpers
# ----------------------------
def normalize_exts(exts: Optional[Iterable[str]]) -> set[str]:
    """Normalize extensions to lowercase with leading '.'."""
    if not exts:
        return set()
    out: set[str] = set()
    for e in exts:
        e = (e or "").strip()
        if not e:
            continue
        if not e.startswith("."):
            e = "." + e
        out.add(e.lower())
    return out


def normalize_keywords(keys: Optional[Iterable[str]]) -> list[str]:
    """Normalize keywords to lowercase; used as substring matches on filename."""
    if not keys:
        return []
    return [k.lower() for k in keys if k and k.strip()]


# ----------------------------
# Filesystem helpers
# ----------------------------
def ensure_dir(path: Path, dry_run: bool, logf) -> None:
    """Create directory if missing (unless dry-run)."""
    if path.exists():
        return
    if dry_run:
        logf(f"[MKDIR] {path}")
        return
    path.mkdir(parents=True, exist_ok=True)
    logf(f"[MKDIR] {path}")


def safe_stat_size_mtime(p: Path) -> Tuple[Optional[int], Optional[float]]:
    try:
        st = p.stat()
        return st.st_size, st.st_mtime
    except OSError:
        return None, None


def same_file_size_and_mtime(src: Path, dst: Path, mtime_tolerance_s: float = 2.0) -> bool:
    """
    Default "already transferred" heuristic for COPY-category files:
    - same size
    - mtimes match within tolerance (filesystem timestamp resolution differences)
    """
    if not dst.exists():
        return False
    ss, sm = safe_stat_size_mtime(src)
    ds, dm = safe_stat_size_mtime(dst)
    if ss is None or ds is None or ss != ds:
        return False
    if sm is None or dm is None:
        return False
    return abs(sm - dm) <= mtime_tolerance_s


# ----------------------------
# Move/copy decision
# ----------------------------
def should_process_by_include_ext(src_file: Path, include_exts: set[str]) -> bool:
    """Optional allow-list filtering: if include_exts is set, skip other extensions."""
    if not include_exts:
        return True
    return src_file.suffix.lower() in include_exts


def should_move(
    src_file: Path,
    file_size_bytes: int,
    max_bytes: int,
    move_exts: set[str],
    move_keywords: list[str],
) -> bool:
    """Return True if a file should be MOVED (otherwise it will be COPIED)."""
    if file_size_bytes > max_bytes:
        return True
    if move_exts and src_file.suffix.lower() in move_exts:
        return True
    if move_keywords:
        name_lc = src_file.name.lower()
        if any(k in name_lc for k in move_keywords):
            return True
    return False


# ----------------------------
# Partial hashing for safety
# ----------------------------
def deterministic_seed(rel_path_str: str, size_bytes: int) -> int:
    """
    Deterministic seed based on file relative path + file size.
    This ensures the sampled offsets are reproducible across runs.
    """
    h = hashlib.blake2b(digest_size=8)
    h.update(rel_path_str.encode("utf-8", errors="ignore"))
    h.update(b"|")
    h.update(str(size_bytes).encode("ascii", errors="ignore"))
    return int.from_bytes(h.digest(), byteorder="big", signed=False)


def partial_hash(
    file_path: Path,
    rel_path_str: str,
    *,
    blocks: int,
    block_size: int,
) -> str:
    """
    Deterministic partial hash:
    - hashes file size + sampled blocks across the file (blake2b)
    - for small files, hashes the full content

    This is a compromise between speed and confidence for very large files.
    """
    size, _ = safe_stat_size_mtime(file_path)
    if size is None:
        raise OSError(f"Cannot stat {file_path}")

    total_sample = blocks * block_size
    h = hashlib.blake2b(digest_size=32)
    h.update(str(size).encode("ascii"))
    h.update(b"|")

    # Small file: hash full content
    if size <= total_sample or size <= block_size:
        with open(file_path, "rb") as f:
            while True:
                chunk = f.read(1024 * 1024)
                if not chunk:
                    break
                h.update(chunk)
        return h.hexdigest()

    rng = random.Random(deterministic_seed(rel_path_str, size))
    max_start = size - block_size

    offsets: set[int] = set()
    attempts = 0
    max_attempts = blocks * 20

    # Choose offsets with 4KB alignment (often a little friendlier for storage)
    while len(offsets) < blocks and attempts < max_attempts:
        attempts += 1
        off = rng.randint(0, max_start)
        off = (off // 4096) * 4096
        offsets.add(min(off, max_start))

    # Fallback if we couldn't get enough unique offsets
    if len(offsets) < blocks:
        offsets = set()
        step = max_start // blocks
        for i in range(blocks):
            offsets.add(min(i * step, max_start))

    with open(file_path, "rb") as f:
        for off in sorted(offsets):
            f.seek(off)
            h.update(f.read(block_size))

    return h.hexdigest()


def partial_hash_match(src: Path, dst: Path, rel_path_str: str, blocks: int, block_size: int) -> bool:
    """Verify src and dst match by (1) size and (2) partial hash."""
    ss, _ = safe_stat_size_mtime(src)
    ds, _ = safe_stat_size_mtime(dst)
    if ss is None or ds is None or ss != ds:
        return False

    return partial_hash(src, rel_path_str, blocks=blocks, block_size=block_size) == partial_hash(
        dst, rel_path_str, blocks=blocks, block_size=block_size
    )


# ----------------------------
# Logging helpers
# ----------------------------
def timestamp_for_log() -> str:
    """YYYYMMDD_HHMMSS"""
    return datetime.now().strftime("%Y%m%d_%H%M%S")


def default_log_filename(ts: str) -> str:
    return f"transferLog_{ts}.log"


def open_log_files(
    source_root: Path,
    target_root: Path,
    *,
    dry_run: bool,
    ts: str,
) -> Tuple[Optional[object], Optional[object], Path, Path]:
    """
    Open source and target log files.
    - Always writes source log (source exists).
    - For target log:
        - In live mode: create target directory and write log there.
        - In dry-run: only write target log if target directory already exists.
    Returns (src_handle, tgt_handle, src_log_path, tgt_log_path).
    """
    src_log_path = source_root / default_log_filename(ts)
    tgt_log_path = target_root / default_log_filename(ts)

    src_handle = None
    tgt_handle = None

    # Source log: always okay (source exists)
    src_handle = open(src_log_path, "a", encoding="utf-8", newline="\n")

    # Target log
    if dry_run:
        if target_root.exists():
            tgt_handle = open(tgt_log_path, "a", encoding="utf-8", newline="\n")
        else:
            tgt_handle = None
    else:
        target_root.mkdir(parents=True, exist_ok=True)
        tgt_handle = open(tgt_log_path, "a", encoding="utf-8", newline="\n")

    return src_handle, tgt_handle, src_log_path, tgt_log_path


# ----------------------------
# Main transfer routine
# ----------------------------
def transfer_tree(
    source_dir: Path,
    target_dir: Path,
    *,
    max_size_gb: float,
    move_exts: set[str],
    move_keywords: list[str],
    include_exts: set[str],
    overwrite: bool,
    dry_run: bool,
    sample_blocks: int,
    sample_block_kb: int,
) -> Tuple[int, int, int, int, Path, Path]:
    """
    Returns:
      (copied, moved, deleted_src, errors, src_log_path, tgt_log_path)

    deleted_src counts cases where:
      - file was MOVE-category,
      - destination already existed,
      - destination verified by partial hash,
      - source deleted instead of moved.
    """
    max_bytes = int(max_size_gb * 1024**3)
    block_size = sample_block_kb * 1024

    copied = moved = deleted_src = errors = 0

    ts = timestamp_for_log()
    src_log_handle, tgt_log_handle, src_log_path, tgt_log_path = open_log_files(
        source_root=source_dir,
        target_root=target_dir,
        dry_run=dry_run,
        ts=ts,
    )

    def logf(msg: str) -> None:
        print(msg)
        if src_log_handle:
            src_log_handle.write(msg + "\n")
            src_log_handle.flush()
        if tgt_log_handle:
            tgt_log_handle.write(msg + "\n")
            tgt_log_handle.flush()

    if dry_run and tgt_log_handle is None:
        logf(f"[WARN] Dry-run: target folder does not exist, so target log was not written: {tgt_log_path}")

    try:
        logf(f"[INFO] Start: {datetime.now().isoformat(timespec='seconds')}")
        logf(f"[INFO] Source: {source_dir}")
        logf(f"[INFO] Target: {target_dir}")
        logf(f"[INFO] Mode: {'DRY RUN' if dry_run else 'LIVE'} | Overwrite: {overwrite}")
        logf(f"[INFO] Default: COPY everything; MOVE only if > {max_size_gb} GB or matches --move-ext/--move-keyword")
        total_mb = (sample_blocks * sample_block_kb) / 1024.0
        logf(f"[INFO] Partial-hash sampling: {sample_blocks} blocks x {sample_block_kb} KB (~{total_mb:.2f} MB/file)")
        logf("[INFO] MOVE-category + dst exists (no --overwrite): delete source ONLY if size + partial-hash match")
        logf("-" * 90)

        # In live mode, ensure target root exists before walking (so we can create subdirs)
        if not dry_run:
            target_dir.mkdir(parents=True, exist_ok=True)

        for root, dirs, files in os.walk(source_dir):
            root_path = Path(root)
            rel_dir = root_path.relative_to(source_dir)
            out_root = target_dir / rel_dir

            ensure_dir(out_root, dry_run=dry_run, logf=logf)
            for d in dirs:
                ensure_dir(out_root / d, dry_run=dry_run, logf=logf)

            for fname in files:
                src_file = root_path / fname

                if not should_process_by_include_ext(src_file, include_exts):
                    logf(f"[SKIP] Not in --include-ext: {src_file}")
                    continue

                dst_file = out_root / fname
                ensure_dir(dst_file.parent, dry_run=dry_run, logf=logf)

                src_size, _ = safe_stat_size_mtime(src_file)
                if src_size is None:
                    logf(f"[ERROR] Cannot stat: {src_file}")
                    errors += 1
                    continue

                do_move = should_move(
                    src_file=src_file,
                    file_size_bytes=src_size,
                    max_bytes=max_bytes,
                    move_exts=move_exts,
                    move_keywords=move_keywords,
                )

                # If destination exists
                if dst_file.exists():
                    if overwrite:
                        if dry_run:
                            logf(f"[DEL ] {dst_file}")
                        else:
                            try:
                                dst_file.unlink()
                                logf(f"[DEL ] {dst_file}")
                            except Exception as e:
                                logf(f"[ERROR] Cannot delete existing dst: {dst_file} ({e})")
                                errors += 1
                                continue
                    else:
                        if do_move:
                            # Default cleanup behavior for MOVE-category:
                            # If destination exists and matches, delete source.
                            rel_path_str = str((rel_dir / fname).as_posix())
                            try:
                                ok = partial_hash_match(
                                    src_file, dst_file, rel_path_str,
                                    blocks=sample_blocks, block_size=block_size
                                )
                            except Exception as e:
                                logf(f"[ERROR] Partial-hash compare failed: {src_file} vs {dst_file} ({e})")
                                errors += 1
                                ok = False

                            if ok:
                                if dry_run:
                                    logf(f"[DEL-SRC] {src_file} (dst exists, MOVE-category, partial-hash match)")
                                else:
                                    try:
                                        src_file.unlink()
                                        logf(f"[DEL-SRC] {src_file} (dst exists, MOVE-category, partial-hash match)")
                                    except Exception as e:
                                        logf(f"[ERROR] Cannot delete source: {src_file} ({e})")
                                        errors += 1
                                        continue
                                deleted_src += 1
                            else:
                                logf(f"[SKIP] dst exists but does NOT match (kept src): {dst_file}")
                            continue

                        # COPY-category: skip logic based on size+mtime
                        if same_file_size_and_mtime(src_file, dst_file):
                            logf(f"[SKIP] Exists (size+mtime match): {dst_file}")
                        else:
                            logf(f"[SKIP] Exists (mismatch; use --overwrite to replace): {dst_file}")
                        continue

                # Destination does not exist (or we deleted it due to overwrite)
                if do_move:
                    if dry_run:
                        logf(f"[MOVE] {src_file} -> {dst_file} ({src_size / 1024**3:.3f} GB)")
                    else:
                        try:
                            shutil.move(str(src_file), str(dst_file))
                            logf(f"[MOVE] {src_file} -> {dst_file} ({src_size / 1024**3:.3f} GB)")
                        except Exception as e:
                            logf(f"[ERROR] MOVE failed: {src_file} -> {dst_file} ({e})")
                            errors += 1
                            continue
                    moved += 1
                else:
                    if dry_run:
                        logf(f"[COPY] {src_file} -> {dst_file} ({src_size / 1024**2:.1f} MB)")
                    else:
                        try:
                            shutil.copy2(str(src_file), str(dst_file))
                            logf(f"[COPY] {src_file} -> {dst_file} ({src_size / 1024**2:.1f} MB)")
                        except Exception as e:
                            logf(f"[ERROR] COPY failed: {src_file} -> {dst_file} ({e})")
                            errors += 1
                            continue
                    copied += 1

        logf("-" * 90)
        logf(f"[INFO] Done: {datetime.now().isoformat(timespec='seconds')}")
        logf(f"[INFO] Copied: {copied} | Moved: {moved} | Deleted-src: {deleted_src} | Errors: {errors}")

        return copied, moved, deleted_src, errors, src_log_path, tgt_log_path

    finally:
        if src_log_handle:
            src_log_handle.close()
        if tgt_log_handle:
            tgt_log_handle.close()


def main() -> int:
    ap = argparse.ArgumentParser(description="Stage data into a derived TAPE_TRANSFER folder by copying/moving files.")
    ap.add_argument("source", help="Source folder path (Windows path or UNC path).")

    # Requested defaults:
    ap.add_argument("--maxSize", type=float, default=10.0,
                    help="Move files larger than this size (GB). Default: 10")

    ap.add_argument("--move-ext", nargs="*", default=None,
                    help="File extensions to ALWAYS move (e.g. .bin .dat .tif).")
    ap.add_argument("--move-keyword", nargs="*", default=None,
                    help="Keywords: if filename contains any, ALWAYS move (case-insensitive).")

    ap.add_argument("--include-ext", nargs="*", default=None,
                    help="Optional allow-list of extensions to process; others are skipped.")
    ap.add_argument("--overwrite", action="store_true",
                    help="Overwrite existing target files (default: skip).")
    ap.add_argument("--dry-run", action="store_true",
                    help="Print actions without copying/moving/deleting (dry-run does not create target dirs).")
    ap.add_argument("--allow-source-in-tape-transfer", action="store_true",
                    help="Allow source paths that already contain TAPE_TRANSFER (not recommended).")

    ap.add_argument("--sample-blocks", type=int, default=DEFAULT_SAMPLE_BLOCKS,
                    help=f"Number of blocks to sample for partial hash. Default: {DEFAULT_SAMPLE_BLOCKS}")
    ap.add_argument("--sample-block-kb", type=int, default=DEFAULT_SAMPLE_BLOCK_KB,
                    help=f"Block size (KB) for partial hash. Default: {DEFAULT_SAMPLE_BLOCK_KB} (~1MB total)")

    args = ap.parse_args()

    src_pw = PureWindowsPath(args.source)
    if path_contains_tape_transfer(src_pw) and not args.allow_source_in_tape_transfer:
        print("[ERROR] Source path contains 'TAPE_TRANSFER'. Refusing by default to avoid modifying staged data.")
        print("        If you really need to run anyway, pass --allow-source-in-tape-transfer.")
        return 2

    tgt_pw = compute_target_path(args.source)
    src = Path(str(src_pw))
    tgt = Path(str(tgt_pw))

    if not src.exists():
        print(f"[ERROR] Source does not exist: {src}")
        return 2
    if not src.is_dir():
        print(f"[ERROR] Source is not a directory: {src}")
        return 2

    move_exts = normalize_exts(args.move_ext)
    include_exts = normalize_exts(args.include_ext)
    move_keywords = normalize_keywords(args.move_keyword)

    print(f"Source: {src}")
    print(f"Target: {tgt}")
    print(f"Mode: {'DRY RUN' if args.dry_run else 'LIVE'} | Overwrite: {args.overwrite}")
    print(f"Default: COPY everything; MOVE only if > {args.maxSize} GB or matches --move-ext/--move-keyword")
    if move_exts:
        print(f"Move extensions: {sorted(move_exts)}")
    if move_keywords:
        print(f"Move keywords: {move_keywords}")
    if include_exts:
        print(f"Include extensions only: {sorted(include_exts)}")
    total_mb = (args.sample_blocks * args.sample_block_kb) / 1024.0
    print(f"Partial-hash sampling: {args.sample_blocks} blocks x {args.sample_block_kb} KB (~{total_mb:.2f} MB/file)")
    print("-" * 90)

    copied, moved, deleted_src, errors, src_log_path, tgt_log_path = transfer_tree(
        source_dir=src,
        target_dir=tgt,
        max_size_gb=args.maxSize,
        move_exts=move_exts,
        move_keywords=move_keywords,
        include_exts=include_exts,
        overwrite=args.overwrite,
        dry_run=args.dry_run,
        sample_blocks=args.sample_blocks,
        sample_block_kb=args.sample_block_kb,
    )

    print("-" * 90)
    print(f"Done. Copied: {copied} | Moved: {moved} | Deleted-src: {deleted_src} | Errors: {errors}")
    print(f"Source log: {src_log_path}")
    print(f"Target log: {tgt_log_path} (may not exist in dry-run if target folder doesn't exist)")
    return 0 if errors == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
