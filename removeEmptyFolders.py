#!/usr/bin/env python3

"""
removeEmptyFolders.py

Recursively finds folders containing no files (empty folders left behind after
serverTransfer.py/tapeTransfer.py move files out of a source tree). A folder
counts as empty if it contains no files anywhere below it (subfolders with only
empty subfolders count too - cascaded bottom-up in a single pass). The root
path itself is never touched.

Default is DRY RUN (prints what would happen). Pass --delete to actually
remove the empty folders, or --move-to <path> to relocate them (preserving
their relative path under the UNC share root) instead of deleting - useful to
visually confirm the moved folders are genuinely empty/zero-size before a
final manual delete.

Usage
-----
python removeEmptyFolders.py "\\naskampa.kampa-10g\lts\TAPE_TRANSFER\BpodBehavior"
python removeEmptyFolders.py "\\naskampa.kampa-10g\lts\TAPE_TRANSFER\BpodBehavior" --delete
python removeEmptyFolders.py "\\naskampa.kampa-10g\lts\TAPE_TRANSFER\BpodBehavior" --move-to "\\naskampa.kampa-10g\lts\emptyFolders" --dry-run
python removeEmptyFolders.py "\\naskampa.kampa-10g\lts\TAPE_TRANSFER\BpodBehavior" --move-to "\\naskampa.kampa-10g\lts\emptyFolders"
"""

import argparse
import os
import shutil
from pathlib import PureWindowsPath


def _relocate_path(dirpath: str, move_to: str) -> str:
    """Mirror dirpath under move_to, dropping dirpath's own UNC/drive root."""
    src = PureWindowsPath(dirpath)
    rel_parts = src.parts[1:]
    dst = PureWindowsPath(move_to)
    return str(PureWindowsPath(*dst.parts, *rel_parts))


def _scan(dirpath: str, action: str, move_to: str, is_root: bool, changed: list) -> bool:
    """
    Post-order scan: recurses into subfolders first, then decides whether
    dirpath itself is (now) empty. A folder is removable if it has no files
    directly in it AND every subfolder it contains was itself removable -
    this correctly cascades multi-level empty trees (e.g. a folder whose
    only contents are now-removed/moved empty subfolders) in a single pass,
    unlike a plain os.walk(topdown=False) which snapshots each folder's
    subdirectory list before descending into it.
    Returns True if dirpath is (now) empty.
    """
    has_file = False
    subdirs = []
    for entry in os.scandir(dirpath):
        if entry.is_dir(follow_symlinks=False):
            subdirs.append(entry.path)
        else:
            has_file = True

    # List comprehension (not a generator passed to all()) so every subfolder is
    # actually visited - all() short-circuits on the first False and would skip
    # scanning later siblings otherwise.
    child_results = [_scan(sd, action, move_to, is_root=False, changed=changed) for sd in subdirs]
    removable = (not has_file) and all(child_results)

    if removable and not is_root:
        changed.append(dirpath)
        if action == "delete":
            os.rmdir(dirpath)
            print(f"[REMOVED] {dirpath}")
        elif action == "move":
            dst = _relocate_path(dirpath, move_to)
            if os.path.isdir(dst):
                # dst already exists as scaffolding created for an already-moved
                # deeper item with the same relative path (e.g. a folder that
                # contains an identically named empty subfolder, like
                # alignMultiROI\alignMultiROI) - it already represents this
                # folder's destination, so just drop the now-empty source shell
                # instead of letting shutil.move nest into it a second time.
                os.rmdir(dirpath)
                print(f"[REMOVED] {dirpath} (destination already exists: {dst})")
            else:
                os.makedirs(os.path.dirname(dst), exist_ok=True)
                shutil.move(dirpath, dst)
                print(f"[MOVED] {dirpath} -> {dst}")
        elif action == "preview-move":
            print(f"[DRY-RUN] Would move: {dirpath} -> {_relocate_path(dirpath, move_to)}")
        else:  # preview-delete
            print(f"[DRY-RUN] Would remove: {dirpath}")

    return removable


def find_empty_folders(root: str, action: str, move_to: str = None) -> int:
    changed: list = []
    _scan(root, action, move_to, is_root=True, changed=changed)
    return len(changed)


def main() -> None:
    ap = argparse.ArgumentParser(description="Find/remove/relocate empty folders under a root path.")
    ap.add_argument("root", help="Root folder to scan (subfolders only; root itself is kept).")
    ap.add_argument("--delete", action="store_true", help="Actually remove empty folders.")
    ap.add_argument("--move-to", default=None,
                     help="Instead of deleting, move empty folders here (mirrors their relative path).")
    ap.add_argument("--dry-run", action="store_true", help="Preview only, no changes.")
    args = ap.parse_args()

    if args.delete and args.move_to:
        raise SystemExit("Use either --delete or --move-to, not both.")

    if args.move_to:
        action = "preview-move" if args.dry_run else "move"
    else:
        action = "preview-delete" if (args.dry_run or not args.delete) else "delete"

    print(f"Mode: {action}")
    if args.move_to:
        print(f"Move target: {args.move_to}")
    count = find_empty_folders(args.root, action, args.move_to)
    verb = {"delete": "Removed", "move": "Moved", "preview-move": "Would move", "preview-delete": "Would remove"}[action]
    print(f"Done. {verb}: {count} folder(s).")


if __name__ == "__main__":
    main()
