#!/usr/bin/env python3

"""
tapeTransfer.py

Purpose
-------
Stage data for tape transfer by mirroring a source directory tree into a derived target directory tree,
with rules for where to insert "TAPE_TRANSFER" into the path. By default, the script COPIES files;
it MOVES only large files (default threshold 10 GB) or files matching explicit "move" criteria.


Examples (PowerShell)
---------------------
1) Basic:
   python tapeTransfer.py "O:\Massive Data Imaging\Proj\Session1"

2) Dry run:
   python tapeTransfer.py "O:\Massive Data Imaging\Proj\Session1" --dry-run

3) Force move some file types / keywords:
   python tapeTransfer.py "D:\data\run1" --move-ext .tif .tiff .bin --move-keyword raw video

4) Ignore manifest (force re-staging checks off):
   python tapeTransfer.py "D:\data\run1" --ignore-manifest
   
   
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
        - On successful DEL-SRC, we also write a manifest record.


Why partial-hash?
----------------
Full hashing of huge files is often too slow (reads all bytes). Partial hashing reads small blocks
spread across the file (default: 16 blocks x 64 KB = ~1 MB), providing high confidence without the
I/O cost of hashing entire 10–200+ GB files. This is meant as a safety check before deleting sources.


Lock file behavior (auto dry-run)
---------------------------------
If the target's TAPE_TRANSFER root folder contains:
    TAPE_TRANSFER_IN_PROGRESS.lock
then the script will FORCE DRY RUN mode (no copying/moving/deleting), and it will print/log a message
that transfers are blocked due to the lock.


Logging (default: enabled)
--------------------------
By default, the script writes a transfer log to BOTH:
- <source_root>\transferLog_YYYYMMDD_HHMMSS.log
- <target_root>\transferLog_YYYYMMDD_HHMMSS.log

Manifest is separate and lives in the source folder:
- <source_root>\.tape_transfer\manifest.ndjson

Dry-run notes:
- --dry-run prints what would happen without copying/moving/deleting.
- It will still write the SOURCE log (source exists).
- It writes the TARGET log only if the target folder already exists (dry-run does not create it).
- In dry-run, the manifest is NOT modified.
  
   
Manifest file
-------------------
This version adds a persistent MANIFEST in the SOURCE folder to prevent re-staging data that has
already been staged/archived, even if the target TAPE_TRANSFER folder gets emptied later.

After each successful file operation (COPY/MOVE/DEL-SRC), the script writes one line to an
append-only manifest file in the source folder:

    <source>\.tape_transfer\manifest.ndjson

Each line is a JSON object containing:
- timestamp
- user
- source root, target root
- relative file path
- size, mtime
- action performed (COPY / MOVE / DEL-SRC)
- optional notes

On subsequent runs, the script loads the manifest and will SKIP files that already have a manifest
entry with the same (relative path, size, mtime). This remains effective even if TAPE_TRANSFER is
emptied by the archiving workflow.
"""

from __future__ import annotations

import argparse
import getpass
import hashlib
import json
import os
import random
import shutil
from datetime import datetime
from pathlib import PureWindowsPath, Path
from typing import Dict, Iterable, Optional, Tuple


# Default partial-hash sampling (~1 MB total)
DEFAULT_SAMPLE_BLOCKS = 16
DEFAULT_SAMPLE_BLOCK_KB = 64  # 16 * 64KB = 1024KB ~ 1MB

LOCK_FILENAME = "TAPE_TRANSFER_IN_PROGRESS.lock"

# Conservative Windows MAX_PATH guard (classic limit is 260; keep buffer for internal handling)
MAX_SAFE_PATH_CHARS = 240


# ----------------------------
# Path mapping
# ----------------------------
def compute_target_path(source: str) -> PureWindowsPath:
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
    return any(part.lower() == "tape_transfer" for part in p.parts)


def tape_transfer_root(p: Path) -> Path:
    parts = list(PureWindowsPath(str(p)).parts)
    for i, part in enumerate(parts):
        if part.lower() == "tape_transfer":
            return Path(str(PureWindowsPath(*parts[: i + 1])))
    return p


# ----------------------------
# CLI parsing helpers
# ----------------------------
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


# ----------------------------
# Filesystem helpers
# ----------------------------
def ensure_dir(path: Path, dry_run: bool, logf) -> None:
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


# ----------------------------
# Partial hashing for safety
# ----------------------------
def deterministic_seed(rel_path_str: str, size_bytes: int) -> int:
    h = hashlib.blake2b(digest_size=8)
    h.update(rel_path_str.encode("utf-8", errors="ignore"))
    h.update(b"|")
    h.update(str(size_bytes).encode("ascii", errors="ignore"))
    return int.from_bytes(h.digest(), byteorder="big", signed=False)


def partial_hash(file_path: Path, rel_path_str: str, *, blocks: int, block_size: int) -> str:
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

    while len(offsets) < blocks and attempts < max_attempts:
        attempts += 1
        off = rng.randint(0, max_start)
        off = (off // 4096) * 4096
        offsets.add(min(off, max_start))

    if len(offsets) < blocks:
        offsets = set()
        step = max_start // blocks if blocks else max_start
        for i in range(blocks):
            offsets.add(min(i * step, max_start))

    with open(file_path, "rb") as f:
        for off in sorted(offsets):
            f.seek(off)
            h.update(f.read(block_size))

    return h.hexdigest()


def partial_hash_match(src: Path, dst: Path, rel_path_str: str, blocks: int, block_size: int) -> bool:
    ss, _ = safe_stat_size_mtime(src)
    ds, _ = safe_stat_size_mtime(dst)
    if ss is None or ds is None or ss != ds:
        return False
    return partial_hash(src, rel_path_str, blocks=blocks, block_size=block_size) == partial_hash(
        dst, rel_path_str, blocks=blocks, block_size=block_size
    )


# ----------------------------
# Manifest (NDJSON, append-only)
# ----------------------------
def manifest_dir(source_root: Path) -> Path:
    return source_root / ".tape_transfer"


def manifest_path(source_root: Path) -> Path:
    return manifest_dir(source_root) / "manifest.ndjson"


def load_manifest_index(source_root: Path, logf, ignore_manifest: bool) -> Dict[str, Tuple[int, float]]:
    """
    Load manifest.ndjson into an index:
      relpath_posix -> (size, mtime)

    If ignore_manifest is True, returns an empty index.
    """
    if ignore_manifest:
        logf("[MANIFEST] Ignoring manifest (--ignore-manifest).")
        return {}

    mpath = manifest_path(source_root)
    if not mpath.exists():
        logf(f"[MANIFEST] No manifest found yet: {mpath}")
        return {}

    index: Dict[str, Tuple[int, float]] = {}
    bad_lines = 0
    total = 0

    try:
        with open(mpath, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                total += 1
                try:
                    rec = json.loads(line)
                    rel = rec.get("relpath")
                    size = rec.get("size")
                    mtime = rec.get("mtime")
                    if isinstance(rel, str) and isinstance(size, int) and isinstance(mtime, (int, float)):
                        # Keep latest for that relpath
                        index[rel] = (int(size), float(mtime))
                except Exception:
                    bad_lines += 1
    except Exception as e:
        logf(f"[MANIFEST][ERROR] Failed reading manifest: {mpath} ({e})")
        return {}

    logf(f"[MANIFEST] Loaded {len(index)} entries from {mpath} (lines={total}, bad_lines={bad_lines})")
    return index


def manifest_has_entry(
    index: Dict[str, Tuple[int, float]],
    relpath_posix: str,
    size: int,
    mtime: float,
    mtime_tolerance_s: float = 2.0,
) -> bool:
    """
    Return True if manifest index contains relpath with matching size and mtime (within tolerance).
    """
    if relpath_posix not in index:
        return False
    s0, t0 = index[relpath_posix]
    return (s0 == size) and (abs(t0 - mtime) <= mtime_tolerance_s)


def append_manifest_record(
    source_root: Path,
    record: dict,
    *,
    dry_run: bool,
    logf,
) -> None:
    """
    Append one JSON record as a line to manifest.ndjson (unless dry_run).
    """
    mdir = manifest_dir(source_root)
    mpath = manifest_path(source_root)

    if dry_run:
        logf(f"[MANIFEST][DRY] Would append record: relpath={record.get('relpath')} action={record.get('action')}")
        return

    try:
        mdir.mkdir(parents=True, exist_ok=True)
        with open(mpath, "a", encoding="utf-8", newline="\n") as f:
            f.write(json.dumps(record, ensure_ascii=False) + "\n")
        logf(f"[MANIFEST] Appended: {record.get('action')} {record.get('relpath')}")
    except Exception as e:
        # We log, but do not stop the transfer; manifest is a robustness aid.
        logf(f"[MANIFEST][ERROR] Failed to append manifest record ({e})")


# ----------------------------
# Logging helpers
# ----------------------------
def timestamp_for_log() -> str:
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
    src_log_path = source_root / default_log_filename(ts)
    tgt_log_path = target_root / default_log_filename(ts)

    src_handle = open(src_log_path, "a", encoding="utf-8", newline="\n")

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
    forced_by_lock: bool,
    lock_file: Path,
    user_name: str,
    ignore_manifest: bool,
) -> Tuple[int, int, int, int, int, Path, Path]:
    """
    Returns:
      (copied, moved, deleted_src, skipped_manifest, errors, src_log_path, tgt_log_path)
    """
    max_bytes = int(max_size_gb * 1024**3)
    block_size = sample_block_kb * 1024

    copied = moved = deleted_src = skipped_manifest = errors = 0

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
        total_mb = (sample_blocks * sample_block_kb) / 1024.0

        # Log header / configuration
        logf(f"[INFO] Start: {datetime.now().isoformat(timespec='seconds')}")
        logf(f"[INFO] User: {user_name}")
        logf(f"[INFO] Source: {source_dir}")
        logf(f"[INFO] Target: {target_dir}")
        logf(f"[INFO] Mode: {'DRY RUN' if dry_run else 'LIVE'} | Overwrite: {overwrite}")
        logf(f"[INFO] maxSizeGB: {max_size_gb}")
        logf(f"[INFO] Partial-hash sampling: {sample_blocks} blocks x {sample_block_kb} KB (~{total_mb:.2f} MB/file)")

        if move_exts:
            logf(f"[INFO] move-ext provided: {sorted(move_exts)}")
        else:
            logf("[INFO] move-ext provided: <none>")

        if move_keywords:
            logf(f"[INFO] move-keyword provided: {move_keywords}")
        else:
            logf("[INFO] move-keyword provided: <none>")

        if include_exts:
            logf(f"[INFO] include-ext provided: {sorted(include_exts)}")
        else:
            logf("[INFO] include-ext provided: <none>")

        if forced_by_lock:
            logf(f"[LOCK] Found lock file: {lock_file}")
            logf("[LOCK] Transfers are blocked. DRY RUN was forced; no data will be copied/moved/deleted.")
        else:
            logf(f"[INFO] Lock check: no lock file found at {lock_file}")

        logf(f"[INFO] Manifest: {manifest_path(source_dir)}")
        logf(f"[INFO] Manifest mode: {'IGNORED' if ignore_manifest else 'ACTIVE'}")
        logf("[INFO] Default: COPY everything; MOVE only if > maxSize or matches --move-ext/--move-keyword")
        logf("[INFO] MOVE-category + dst exists (no --overwrite): delete source ONLY if size + partial-hash match")
        logf("-" * 110)

        # Load manifest index (for skip decisions)
        manifest_index = load_manifest_index(source_dir, logf=logf, ignore_manifest=ignore_manifest)

        # In live mode, ensure target root exists before walking
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
                # Skip logs and manifest folder itself to avoid re-transferring control files
                if fname.startswith("transferLog_") and fname.endswith(".log"):
                    continue

                src_file = root_path / fname

                # Never transfer the manifest directory itself
                if ".tape_transfer" in src_file.parts:
                    continue

                if not should_process_by_include_ext(src_file, include_exts):
                    logf(f"[SKIP] Not in --include-ext: {src_file}")
                    continue

                dst_file = out_root / fname
                
                # --- PATH LENGTH GUARD (warn + skip) ---
                # Classic Windows APIs can fail beyond ~260 characters. We warn early and skip to avoid hard errors.
                dst_str = str(dst_file)
                if len(dst_str) > MAX_SAFE_PATH_CHARS:
                    logf(f"[PATH-ERROR] Destination path too long ({len(dst_str)} chars > {MAX_SAFE_PATH_CHARS}). Skipping: {dst_str}")
                    errors += 1
                    continue
    
                ensure_dir(dst_file.parent, dry_run=dry_run, logf=logf)

                src_size, src_mtime = safe_stat_size_mtime(src_file)
                if src_size is None or src_mtime is None:
                    logf(f"[ERROR] Cannot stat: {src_file}")
                    errors += 1
                    continue

                rel_path_posix = str((rel_dir / fname).as_posix())

                # Decide move/copy classification under *current* rules
                do_move = should_move(
                    src_file=src_file,
                    file_size_bytes=int(src_size),
                    max_bytes=max_bytes,
                    move_exts=move_exts,
                    move_keywords=move_keywords,
                )

                # --- NEW: cleanup path BEFORE manifest skip ---
                # If under current rules this file should be MOVED, but it already exists in target,
                # then delete the source after verifying dst matches src (size + partial hash).
                if dst_file.exists() and (not overwrite) and do_move:
                    try:
                        ok = partial_hash_match(
                            src_file, dst_file, rel_path_posix,
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
                                # If we couldn't delete, keep going (do not treat as staged)
                                ok = False

                        if ok:
                            deleted_src += 1
                            # Write a manifest record even if it already existed; it documents the cleanup event.
                            rec = {
                                "ts": datetime.now().isoformat(timespec="seconds"),
                                "user": user_name,
                                "source_root": str(source_dir),
                                "target_root": str(target_dir),
                                "relpath": rel_path_posix,
                                "size": int(src_size),
                                "mtime": float(src_mtime),
                                "action": "DEL-SRC",
                                "note": "cleanup: dst existed; verified by partial hash; deleted source under current move rules",
                            }
                            append_manifest_record(source_dir, rec, dry_run=dry_run, logf=logf)
                            manifest_index[rel_path_posix] = (int(src_size), float(src_mtime))
                            continue
                    else:
                        # dst exists but mismatch -> do NOT delete source
                        logf(f"[SKIP] dst exists but does NOT match (kept src): {dst_file}")
                        continue

                # --- Manifest-based skip (only for staging actions) ---
                # If we already have a manifest entry for this file version, don't re-stage it.
                if manifest_has_entry(manifest_index, rel_path_posix, int(src_size), float(src_mtime)):
                    logf(f"[SKIP-MANIFEST] Already staged/archived per manifest: {rel_path_posix}")
                    skipped_manifest += 1
                    continue

                # If destination exists and overwrite is requested, delete destination and proceed.
                if dst_file.exists() and overwrite:
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

                # Destination does not exist (or we deleted it due to overwrite)
                if do_move:
                    if dry_run:
                        logf(f"[MOVE] {src_file} -> {dst_file} ({int(src_size) / 1024**3:.3f} GB)")
                    else:
                        try:
                            shutil.move(str(src_file), str(dst_file))
                            logf(f"[MOVE] {src_file} -> {dst_file} ({int(src_size) / 1024**3:.3f} GB)")
                        except Exception as e:
                            logf(f"[ERROR] MOVE failed: {src_file} -> {dst_file} ({e})")
                            errors += 1
                            continue
                    moved += 1

                    # Manifest record for MOVE
                    rec = {
                        "ts": datetime.now().isoformat(timespec="seconds"),
                        "user": user_name,
                        "source_root": str(source_dir),
                        "target_root": str(target_dir),
                        "relpath": rel_path_posix,
                        "size": int(src_size),
                        "mtime": float(src_mtime),
                        "action": "MOVE",
                    }
                    append_manifest_record(source_dir, rec, dry_run=dry_run, logf=logf)
                    manifest_index[rel_path_posix] = (int(src_size), float(src_mtime))

                else:
                    if dry_run:
                        logf(f"[COPY] {src_file} -> {dst_file} ({int(src_size) / 1024**2:.1f} MB)")
                    else:
                        try:
                            shutil.copy2(str(src_file), str(dst_file))
                            logf(f"[COPY] {src_file} -> {dst_file} ({int(src_size) / 1024**2:.1f} MB)")
                        except Exception as e:
                            logf(f"[ERROR] COPY failed: {src_file} -> {dst_file} ({e})")
                            errors += 1
                            continue
                    copied += 1

                    # Manifest record for COPY
                    rec = {
                        "ts": datetime.now().isoformat(timespec="seconds"),
                        "user": user_name,
                        "source_root": str(source_dir),
                        "target_root": str(target_dir),
                        "relpath": rel_path_posix,
                        "size": int(src_size),
                        "mtime": float(src_mtime),
                        "action": "COPY",
                    }
                    append_manifest_record(source_dir, rec, dry_run=dry_run, logf=logf)
                    manifest_index[rel_path_posix] = (int(src_size), float(src_mtime))

        logf("-" * 110)
        logf(f"[INFO] Done: {datetime.now().isoformat(timespec='seconds')}")
        logf(f"[INFO] Copied: {copied} | Moved: {moved} | Deleted-src: {deleted_src} | "
             f"Skipped(manifest): {skipped_manifest} | Errors: {errors}")

        return copied, moved, deleted_src, skipped_manifest, errors, src_log_path, tgt_log_path

    finally:
        if src_log_handle:
            src_log_handle.close()
        if tgt_log_handle:
            tgt_log_handle.close()


def main() -> int:
    ap = argparse.ArgumentParser(description="Stage data into a derived TAPE_TRANSFER folder by copying/moving files.")
    ap.add_argument("source", help="Source folder path (Windows path or UNC path).")

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

    ap.add_argument("--ignore-manifest", action="store_true",
                    help="Ignore manifest and process files as if none were previously staged/archived.")

    args = ap.parse_args()

    user_name = getpass.getuser()

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

    # LOCK CHECK (auto dry-run)
    tape_root = tape_transfer_root(tgt)
    lock_file = tape_root / LOCK_FILENAME
    forced_by_lock = False
    if lock_file.exists():
        forced_by_lock = True
        args.dry_run = True
        print(f"[LOCK] Found lock file: {lock_file}")
        print("[LOCK] TAPE_TRANSFER is currently in progress.")
        print("[LOCK] No data will be copied/moved/deleted. Running in DRY RUN mode.\n")

    move_exts = normalize_exts(args.move_ext)
    include_exts = normalize_exts(args.include_ext)
    move_keywords = normalize_keywords(args.move_keyword)

    total_mb = (args.sample_blocks * args.sample_block_kb) / 1024.0

    print(f"User: {user_name}")
    print(f"Source: {src}")
    print(f"Target: {tgt}")
    print(f"TAPE_TRANSFER root: {tape_root}")
    print(f"Mode: {'DRY RUN' if args.dry_run else 'LIVE'} | Overwrite: {args.overwrite}")
    if forced_by_lock:
        print("NOTE: DRY RUN was forced due to TAPE_TRANSFER_IN_PROGRESS.lock")
    print(f"maxSize: {args.maxSize} GB")
    print(f"move-ext: {sorted(move_exts) if move_exts else '<none>'}")
    print(f"move-keyword: {move_keywords if move_keywords else '<none>'}")
    print(f"include-ext: {sorted(include_exts) if include_exts else '<none>'}")
    print(f"Partial-hash sampling: {args.sample_blocks} blocks x {args.sample_block_kb} KB (~{total_mb:.2f} MB/file)")
    print(f"Manifest: {manifest_path(src)} ({'ignored' if args.ignore_manifest else 'active'})")
    print("-" * 110)

    copied, moved, deleted_src, skipped_manifest, errors, src_log_path, tgt_log_path = transfer_tree(
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
        forced_by_lock=forced_by_lock,
        lock_file=lock_file,
        user_name=user_name,
        ignore_manifest=args.ignore_manifest,
    )

    print("-" * 110)
    print(f"Done. Copied: {copied} | Moved: {moved} | Deleted-src: {deleted_src} | "
          f"Skipped(manifest): {skipped_manifest} | Errors: {errors}")
    print(f"Source log: {src_log_path}")
    print(f"Target log: {tgt_log_path} (may not exist in dry-run if target folder doesn't exist)")
    print(f"Manifest: {manifest_path(src)}")

    # If we were blocked by lock, return a distinct code (useful for automation)
    if forced_by_lock:
        return 3
    return 0 if errors == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
