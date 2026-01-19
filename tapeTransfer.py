#!/usr/bin/env python3

"""
Created on Mon Jan 19 23:00:49 2026
@author: Simon

tapeTransfer.py

Default behavior:
- Copy all files.
- Move only if:
  (a) size > --maxSize (GB), OR
  (b) extension matches --move-ext, OR
  (c) filename contains --move-keyword

Target path rules:
1) O:\Massive Data Imaging\RemainingPath
   -> O:\Massive Data Imaging\TAPE_TRANSFER\RemainingPath
2) Otherwise insert immediately after drive/share root:
   D:\foo\bar           -> D:\TAPE_TRANSFER\foo\bar
   \\srv\share\foo\bar  -> \\srv\share\TAPE_TRANSFER\foo\bar

Existing-file decision (when --overwrite is NOT used):
- Skip only if size matches AND mtime matches (default).

Examples:
  python tapeTransfer.py "O:\\Massive Data Imaging\\Group\\Proj\\raw\\Rec1"
  python tapeTransfer.py "D:\\data\\run1" --move-ext .bin .dat --move-keyword raw video
  python tapeTransfer.py "\\\\server\\share\\data\\run1" --dry-run --log transfer.log
"""

from __future__ import annotations

import argparse
import os
import shutil
import sys
from pathlib import PureWindowsPath, Path
from typing import Iterable, Optional, Tuple


def compute_target_path(source: str) -> PureWindowsPath:
    p = PureWindowsPath(source)
    parts = list(p.parts)
    if not parts:
        raise ValueError("Empty source path.")

    # Rule 1: O:\Massive Data Imaging\...
    if len(parts) >= 2 and parts[0].lower() == "o:\\" and parts[1].lower() == "massive data imaging":
        return PureWindowsPath(parts[0], parts[1], "TAPE_TRANSFER", *parts[2:])

    # Rule 2: insert immediately after the root (drive/share anchor)
    return PureWindowsPath(parts[0], "TAPE_TRANSFER", *parts[1:])


def normalize_exts(exts: Optional[Iterable[str]]) -> set[str]:
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
    if not keys:
        return []
    return [k.lower() for k in keys if k and k.strip()]


def ensure_dir(path: Path, dry_run: bool, logf) -> None:
    if path.exists():
        return
    if dry_run:
        logf(f"[MKDIR] {path}")
        return
    path.mkdir(parents=True, exist_ok=True)
    logf(f"[MKDIR] {path}")


def mtime_seconds(p: Path) -> Optional[float]:
    try:
        return p.stat().st_mtime
    except OSError:
        return None


def size_bytes(p: Path) -> Optional[int]:
    try:
        return p.stat().st_size
    except OSError:
        return None


def same_file_size_and_mtime(src: Path, dst: Path, mtime_tolerance_s: float = 2.0) -> bool:
    """
    Returns True if size matches and mtimes match within tolerance.
    Tolerance helps with filesystem timestamp resolution differences.
    """
    if not dst.exists():
        return False

    ss = size_bytes(src)
    ds = size_bytes(dst)
    if ss is None or ds is None or ss != ds:
        return False

    sm = mtime_seconds(src)
    dm = mtime_seconds(dst)
    if sm is None or dm is None:
        return False

    return abs(sm - dm) <= mtime_tolerance_s


def should_process_by_include_ext(src_file: Path, include_exts: set[str]) -> bool:
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
    if file_size_bytes > max_bytes:
        return True
    if move_exts and src_file.suffix.lower() in move_exts:
        return True
    if move_keywords:
        name_lc = src_file.name.lower()
        if any(k in name_lc for k in move_keywords):
            return True
    return False


def transfer_tree(
    source_dir: Path,
    target_dir: Path,
    max_size_gb: float,
    move_exts: set[str],
    move_keywords: list[str],
    include_exts: set[str],
    overwrite: bool,
    dry_run: bool,
    log_path: Optional[Path],
) -> Tuple[int, int, int, int]:
    """
    Returns: (copied, moved, skipped, errors)
    """
    max_bytes = int(max_size_gb * 1024**3)
    copied = moved = skipped = errors = 0

    log_handle = None
    try:
        if log_path:
            log_handle = open(log_path, "a", encoding="utf-8", newline="\n")

        def logf(msg: str) -> None:
            print(msg)
            if log_handle:
                log_handle.write(msg + "\n")
                log_handle.flush()

        for root, dirs, files in os.walk(source_dir):
            root_path = Path(root)
            rel = root_path.relative_to(source_dir)
            out_root = target_dir / rel

            ensure_dir(out_root, dry_run=dry_run, logf=logf)
            for d in dirs:
                ensure_dir(out_root / d, dry_run=dry_run, logf=logf)

            for fname in files:
                src_file = root_path / fname

                if not should_process_by_include_ext(src_file, include_exts):
                    logf(f"[SKIP] Not in --include-ext: {src_file}")
                    skipped += 1
                    continue

                dst_file = out_root / fname
                ensure_dir(dst_file.parent, dry_run=dry_run, logf=logf)

                # If destination exists:
                if dst_file.exists():
                    if not overwrite:
                        if same_file_size_and_mtime(src_file, dst_file):
                            logf(f"[SKIP] Exists (size+mtime match): {dst_file}")
                        else:
                            logf(f"[SKIP] Exists (mismatch; use --overwrite to replace): {dst_file}")
                        skipped += 1
                        continue
                    else:
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

                try:
                    size = src_file.stat().st_size
                except OSError as e:
                    logf(f"[ERROR] Cannot stat: {src_file} ({e})")
                    errors += 1
                    continue

                do_move = should_move(
                    src_file=src_file,
                    file_size_bytes=size,
                    max_bytes=max_bytes,
                    move_exts=move_exts,
                    move_keywords=move_keywords,
                )

                if do_move:
                    if dry_run:
                        logf(f"[MOVE] {src_file} -> {dst_file} ({size / 1024**3:.3f} GB)")
                    else:
                        try:
                            shutil.move(str(src_file), str(dst_file))
                            logf(f"[MOVE] {src_file} -> {dst_file} ({size / 1024**3:.3f} GB)")
                        except Exception as e:
                            logf(f"[ERROR] MOVE failed: {src_file} -> {dst_file} ({e})")
                            errors += 1
                            continue
                    moved += 1
                else:
                    if dry_run:
                        logf(f"[COPY] {src_file} -> {dst_file} ({size / 1024**2:.1f} MB)")
                    else:
                        try:
                            shutil.copy2(str(src_file), str(dst_file))
                            logf(f"[COPY] {src_file} -> {dst_file} ({size / 1024**2:.1f} MB)")
                        except Exception as e:
                            logf(f"[ERROR] COPY failed: {src_file} -> {dst_file} ({e})")
                            errors += 1
                            continue
                    copied += 1

        return copied, moved, skipped, errors

    finally:
        if log_handle:
            log_handle.close()


def path_contains_tape_transfer(p: PureWindowsPath) -> bool:
    return any(part.lower() == "tape_transfer" for part in p.parts)


def main() -> int:
    ap = argparse.ArgumentParser(description="Stage data into a derived TAPE_TRANSFER folder by copying/moving files.")
    ap.add_argument("source", help="Source folder path (Windows path or UNC path).")

    # Defaults requested:
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
                    help="Print actions without modifying anything.")
    ap.add_argument("--log", default=None,
                    help="Optional log file path (appends).")
    ap.add_argument("--allow-source-in-tape-transfer", action="store_true",
                    help="Allow source paths that already contain TAPE_TRANSFER (not recommended).")

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
    log_path = Path(args.log) if args.log else None

    print(f"Source: {src}")
    print(f"Target: {tgt}")
    print(f"Default: COPY everything; MOVE only if > {args.maxSize} GB or matches --move-ext/--move-keyword")
    print(f"Existing-file check (when not overwriting): size + mtime match => skip")
    if move_exts:
        print(f"Move extensions: {sorted(move_exts)}")
    if move_keywords:
        print(f"Move keywords: {move_keywords}")
    if include_exts:
        print(f"Include extensions only: {sorted(include_exts)}")
    print(f"Mode: {'DRY RUN' if args.dry_run else 'LIVE'} | Overwrite: {args.overwrite}")
    if log_path:
        print(f"Log: {log_path} (append)")
    print("-" * 70)

    if not args.dry_run:
        tgt.mkdir(parents=True, exist_ok=True)

    copied, moved, skipped, errors = transfer_tree(
        source_dir=src,
        target_dir=tgt,
        max_size_gb=args.maxSize,
        move_exts=move_exts,
        move_keywords=move_keywords,
        include_exts=include_exts,
        overwrite=args.overwrite,
        dry_run=args.dry_run,
        log_path=log_path,
    )

    print("-" * 70)
    print(f"Done. Copied: {copied} | Moved: {moved} | Skipped: {skipped} | Errors: {errors}")
    return 0 if errors == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
