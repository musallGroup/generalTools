#!/usr/bin/env python3

"""
tapeTransferOrphanCleanup.py

Purpose
-------
Companion to tapeTransfer.py. Finds "orphaned" source files: files whose
size+mtime match a manifest entry (i.e. tapeTransfer.py already staged them
at some point), which currently qualify as MOVE-category (large files) under
the same --maxSize/--move-ext/--move-keyword rules as tapeTransfer.py, but
whose copy under TAPE_TRANSFER no longer exists (already cleared out /
archived to tape).

tapeTransfer.py deliberately never deletes a source file unless it can verify
it against a live copy at the destination (partial-hash match). Once a
TAPE_TRANSFER folder is emptied after archiving, that verification is no
longer possible, so tapeTransfer.py just skips those files forever
(SKIP-MANIFEST) and leaves the source copy in place. This script handles that
remaining case deliberately, as a separate, narrower tool.

Safety notes
------------
This script can NEVER confirm a file actually made it onto tape - the
manifest only proves it made it into TAPE_TRANSFER at some point. Treat the
report as a candidate list, not a guarantee.

- Default mode is DRY RUN: it only writes a report of candidates, no deletes.
- --delete is required to actually remove files, and even then only files
  whose manifest timestamp is older than --min-age-days are eligible, as a
  buffer for IT's tape process to have finished.
- If a TAPE_TRANSFER_IN_PROGRESS.lock or TAPE_COPY_IN_PROGRESS_*.lock is
  present at the TAPE_TRANSFER root, this script forces dry-run, same as
  tapeTransfer.py, since a run in progress makes the comparison unreliable.
- If the TAPE_TRANSFER root itself does not exist on disk, the script refuses
  to run rather than treat every staged file as "orphaned" - a missing root
  more likely means misconfiguration than confirmed archival.


Examples (PowerShell)
----------------------
1) Dry run (default), report only:
   python tapeTransferOrphanCleanup.py "\\naskampa\lts\BpodBehavior\462"

2) Actually delete eligible orphans (>=30 days old by default):
   python tapeTransferOrphanCleanup.py "\\naskampa\lts\BpodBehavior\462" --delete

3) Shorter safety window, matching custom move rules used originally:
   python tapeTransferOrphanCleanup.py "D:\data\run1" --move-ext .tif --min-age-days 14


Report / log output
--------------------
Both written to the SOURCE folder on every run (dry-run or --delete):
- <source_root>\orphanCandidates_YYYYMMDD_HHMMSS.txt   (one line per candidate)
- <source_root>\orphanCleanupLog_YYYYMMDD_HHMMSS.log   (full run log)

Deletions (only with --delete) are appended to the same manifest used by
tapeTransfer.py, with action "DEL-SRC-ORPHAN".
"""

from __future__ import annotations

__version__ = "1.0.0"
__author__  = "Simon Musall"
__email__   = "s.musall@fz-juelich.de"

import argparse
import getpass
import json
import os
from datetime import datetime
from pathlib import Path
from typing import Dict

from tapeTransfer import (
    LOCK_FILENAME,
    COPY_LOCK_PREFIX,
    compute_target_path,
    tape_transfer_root,
    manifest_path,
    append_manifest_record,
    normalize_exts,
    normalize_keywords,
    path_contains_tape_transfer,
    safe_stat_size_mtime,
    should_move,
)

MTIME_TOLERANCE_S = 2.0


def load_manifest_full(source_root: Path) -> Dict[str, dict]:
    """relpath -> most recent manifest record (last line wins, same as tapeTransfer.py)."""
    mpath = manifest_path(source_root)
    index: Dict[str, dict] = {}
    if not mpath.exists():
        return index
    with open(mpath, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                rec = json.loads(line)
                rel = rec.get("relpath")
                if isinstance(rel, str):
                    index[rel] = rec
            except Exception:
                continue
    return index


def manifest_record_matches(rec: dict, size: int, mtime: float) -> bool:
    rsize = rec.get("size")
    rmtime = rec.get("mtime")
    if not isinstance(rsize, int) or not isinstance(rmtime, (int, float)):
        return False
    return rsize == size and abs(float(rmtime) - mtime) <= MTIME_TOLERANCE_S


def timestamp_for_log() -> str:
    return datetime.now().strftime("%Y%m%d_%H%M%S")


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Find (and optionally delete) source files already archived to TAPE_TRANSFER but no longer present there."
    )
    ap.add_argument("source", help="Source folder path (same one originally passed to tapeTransfer.py).")

    ap.add_argument("--maxSize", type=float, default=20.0,
                    help="Must match the --maxSize used by tapeTransfer.py for this source. Default: 20")
    ap.add_argument("--move-ext", nargs="*", default=None,
                    help="Must match the --move-ext used by tapeTransfer.py for this source.")
    ap.add_argument("--move-keyword", nargs="*", default=None,
                    help="Must match the --move-keyword used by tapeTransfer.py for this source.")

    ap.add_argument("--min-age-days", type=float, default=30.0,
                    help="Minimum age (days, since the manifest timestamp) before a candidate is eligible for --delete. Default: 30")

    ap.add_argument("--delete", action="store_true",
                    help="Actually delete eligible orphaned source files. Default: dry-run (report only).")

    args = ap.parse_args()

    user_name = getpass.getuser()
    src_pw = Path(args.source)

    if path_contains_tape_transfer(src_pw):
        print("[ERROR] Source path contains 'TAPE_TRANSFER'. Refusing to run on a staging path.")
        return 2

    src = Path(str(src_pw))
    if not src.exists() or not src.is_dir():
        print(f"[ERROR] Source is not a directory: {src}")
        return 2

    target_root = Path(str(compute_target_path(args.source)))
    tape_root = tape_transfer_root(target_root)

    if not tape_root.exists():
        print(f"[ERROR] TAPE_TRANSFER root does not exist: {tape_root}")
        print("        Refusing to run - a missing root more likely means misconfiguration than confirmed archival.")
        return 2

    dry_run = not args.delete

    lock_file = tape_root / LOCK_FILENAME
    existing_copy_locks = sorted(tape_root.glob(f"{COPY_LOCK_PREFIX}_*.lock"))
    forced_by_lock = lock_file.exists() or bool(existing_copy_locks)
    if forced_by_lock and not dry_run:
        dry_run = True
        print("[LOCK] A tapeTransfer.py run is in progress or was interrupted. Forcing DRY RUN.")

    move_exts = normalize_exts(args.move_ext)
    include_keywords = normalize_keywords(args.move_keyword)
    max_bytes = int(args.maxSize * 1024**3)

    ts = timestamp_for_log()
    report_path = src / f"orphanCandidates_{ts}.txt"
    log_path = src / f"orphanCleanupLog_{ts}.log"

    log_handle = open(log_path, "a", encoding="utf-8", newline="\n")

    def logf(msg: str) -> None:
        print(msg)
        log_handle.write(msg + "\n")
        log_handle.flush()

    logf(f"[INFO] Start: {datetime.now().isoformat(timespec='seconds')}")
    logf(f"[INFO] User: {user_name}")
    logf(f"[INFO] Source: {src}")
    logf(f"[INFO] TAPE_TRANSFER target root: {tape_root}")
    logf(f"[INFO] Mode: {'DELETE' if not dry_run else 'DRY RUN'}")
    logf(f"[INFO] maxSizeGB: {args.maxSize} | move-ext: {sorted(move_exts) if move_exts else '<none>'} | move-keyword: {include_keywords if include_keywords else '<none>'}")
    logf(f"[INFO] min-age-days: {args.min_age_days}")
    if forced_by_lock:
        logf(f"[LOCK] Found lock at {tape_root}; forced DRY RUN regardless of --delete.")
    logf("-" * 110)

    manifest_index = load_manifest_full(src)
    logf(f"[MANIFEST] Loaded {len(manifest_index)} entries from {manifest_path(src)}")

    candidates = []  # (relpath, src_file, size, rec)
    checked = 0

    for root, dirs, files in os.walk(src):
        root_path = Path(root)
        rel_dir = root_path.relative_to(src)

        for fname in files:
            if fname.startswith(("transferLog_", "orphanCandidates_", "orphanCleanupLog_")):
                continue
            src_file = root_path / fname
            if ".tape_transfer" in src_file.parts:
                continue

            checked += 1
            src_size, src_mtime = safe_stat_size_mtime(src_file)
            if src_size is None or src_mtime is None:
                continue

            rel_path_posix = str((rel_dir / fname).as_posix())
            rec = manifest_index.get(rel_path_posix)
            if rec is None or not manifest_record_matches(rec, int(src_size), float(src_mtime)):
                continue

            if not should_move(src_file, int(src_size), max_bytes, move_exts, include_keywords):
                continue  # COPY-category files are meant to stay in source forever

            dst_file = target_root / rel_dir / fname
            if dst_file.exists():
                continue  # not orphaned - tapeTransfer.py's own DEL-SRC verification path covers this

            candidates.append((rel_path_posix, src_file, int(src_size), rec))

    logf(f"[INFO] Files checked: {checked} | Orphan candidates found: {len(candidates)}")
    logf("-" * 110)

    now = datetime.now()
    eligible_count = 0
    deleted = 0
    errors = 0

    with open(report_path, "w", encoding="utf-8", newline="\n") as rpt:
        rpt.write(f"# orphan candidates for {src}\n")
        rpt.write(f"# generated {now.isoformat(timespec='seconds')} by {user_name}\n")
        rpt.write(f"# min-age-days={args.min_age_days} maxSize={args.maxSize}GB move-ext={sorted(move_exts)} move-keyword={include_keywords}\n")
        rpt.write("# relpath | size_GB | manifest_action | manifest_ts | age_days | eligible | source_path\n")

        for rel_path_posix, src_file, size, rec in candidates:
            action = rec.get("action", "?")
            rec_ts = rec.get("ts")
            try:
                age_days = (now - datetime.fromisoformat(rec_ts)).total_seconds() / 86400.0
            except Exception:
                age_days = None

            eligible = age_days is not None and age_days >= args.min_age_days
            if eligible:
                eligible_count += 1

            size_gb = size / 1024**3
            line = (f"{rel_path_posix} | {size_gb:.3f} GB | {action} | {rec_ts} | "
                    f"{'?' if age_days is None else f'{age_days:.1f}'} | "
                    f"{'ELIGIBLE' if eligible else 'TOO_RECENT'} | {src_file}")
            rpt.write(line + "\n")
            logf(f"[CANDIDATE] {line}")

            if not dry_run and eligible:
                try:
                    src_file.unlink()
                    logf(f"[DEL-SRC-ORPHAN] {src_file}")
                    deleted += 1
                    del_rec = {
                        "ts": datetime.now().isoformat(timespec="seconds"),
                        "user": user_name,
                        "source_root": str(src),
                        "target_root": str(target_root),
                        "relpath": rel_path_posix,
                        "size": size,
                        "mtime": rec.get("mtime"),
                        "action": "DEL-SRC-ORPHAN",
                        "note": (f"orphan cleanup: dst missing under TAPE_TRANSFER (assumed archived to tape); "
                                 f"size+mtime matched manifest entry from {rec_ts} (action={action}); "
                                 f"no live hash verification possible; age_days={age_days:.1f} >= min_age_days={args.min_age_days}"),
                    }
                    append_manifest_record(src, del_rec, dry_run=False, logf=logf)
                except Exception as e:
                    logf(f"[ERROR] Cannot delete source: {src_file} ({e})")
                    errors += 1

    logf("-" * 110)
    logf(f"[INFO] Done: {datetime.now().isoformat(timespec='seconds')}")
    logf(f"[INFO] Candidates: {len(candidates)} | Eligible: {eligible_count} | "
         f"Deleted: {deleted} | Errors: {errors}")
    logf(f"[INFO] Report: {report_path}")
    logf(f"[INFO] Log: {log_path}")

    log_handle.close()

    return 0 if errors == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
