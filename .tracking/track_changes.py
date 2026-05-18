#!/usr/bin/env python3
"""
Gemini Change Tracker — records file-level changes with diffs and metadata.

Usage:
    python .tracking/track_changes.py --author gemini --message "what changed and why"
    python .tracking/track_changes.py --snapshot   # take baseline snapshot
    python .tracking/track_changes.py --diff       # show diff from last snapshot
"""

import argparse
import json
import hashlib
import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

TRACKING_DIR = Path(__file__).parent
LOG_FILE = TRACKING_DIR / "gemini_changes.jsonl"
SNAPSHOT_FILE = TRACKING_DIR / "baseline_snapshot.json"
REPO_ROOT = TRACKING_DIR.parent

EXCLUDE_DIRS = {".git", ".snakemake", "__pycache__", ".tracking", "logs", "data", "results"}
EXCLUDE_EXTS = {".pyc", ".pyo", ".so", ".bak", ".swp", ".swo"}


def get_file_hash(filepath):
    h = hashlib.sha256()
    try:
        with open(filepath, "rb") as f:
            for chunk in iter(lambda: f.read(8192), b""):
                h.update(chunk)
        return h.hexdigest()
    except (OSError, PermissionError):
        return None


def get_repo_files():
    """Get all tracked files in the repo, excluding ignored dirs."""
    files = {}
    for root, dirs, filenames in os.walk(REPO_ROOT):
        dirs[:] = [d for d in dirs if d not in EXCLUDE_DIRS and not d.startswith(".")]
        for fn in filenames:
            filepath = Path(root) / fn
            if filepath.suffix in EXCLUDE_EXTS:
                continue
            rel = filepath.relative_to(REPO_ROOT)
            file_hash = get_file_hash(filepath)
            if file_hash:
                files[str(rel)] = {
                    "hash": file_hash,
                    "size": filepath.stat().st_size,
                    "mtime": filepath.stat().st_mtime,
                }
    return files


def get_git_diff():
    """Get current unstaged + staged git diff."""
    diff = ""
    try:
        diff += subprocess.run(
            ["git", "diff", "HEAD"],
            capture_output=True, text=True, cwd=REPO_ROOT
        ).stdout
        diff += subprocess.run(
            ["git", "diff", "--cached"],
            capture_output=True, text=True, cwd=REPO_ROOT
        ).stdout
    except Exception:
        pass
    return diff


def get_untracked_files():
    """Get list of untracked files."""
    try:
        result = subprocess.run(
            ["git", "ls-files", "--others", "--exclude-standard"],
            capture_output=True, text=True, cwd=REPO_ROOT
        )
        return [line.strip() for line in result.stdout.splitlines() if line.strip()]
    except Exception:
        return []


def snapshot():
    """Take a baseline snapshot of all files."""
    files = get_repo_files()
    snapshot_data = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "commit": subprocess.run(
            ["git", "rev-parse", "HEAD"], capture_output=True, text=True, cwd=REPO_ROOT
        ).stdout.strip(),
        "files": files,
    }
    with open(SNAPSHOT_FILE, "w") as f:
        json.dump(snapshot_data, f, indent=2)
    print(f"[snapshot] Baseline saved: {len(files)} files at {snapshot_data['timestamp']}")
    return snapshot_data


def diff():
    """Show differences from the last snapshot."""
    if not SNAPSHOT_FILE.exists():
        print("[diff] No baseline snapshot found. Run --snapshot first.")
        return

    with open(SNAPSHOT_FILE) as f:
        baseline = json.load(f)

    current = get_repo_files()
    baseline_files = baseline["files"]

    added = set(current.keys()) - set(baseline_files.keys())
    removed = set(baseline_files.keys()) - set(current.keys())
    modified = {
        f for f in set(current.keys()) & set(baseline_files.keys())
        if current[f]["hash"] != baseline_files[f]["hash"]
    }

    print(f"[diff] Since {baseline['timestamp']} (commit {baseline['commit'][:8]}):")
    print(f"  + Added:     {len(added)} files")
    for f in sorted(added):
        print(f"    + {f}")
    print(f"  - Removed:   {len(removed)} files")
    for f in sorted(removed):
        print(f"    - {f}")
    print(f"  ~ Modified:  {len(modified)} files")
    for f in sorted(modified):
        old_size = baseline_files[f]["size"]
        new_size = current[f]["size"]
        delta = new_size - old_size
        sign = "+" if delta >= 0 else ""
        print(f"    ~ {f} ({sign}{delta} bytes)")

    git_diff = get_git_diff()
    if git_diff:
        print(f"\n[git diff] {len(git_diff.splitlines())} lines of diff:")
        print(git_diff[:5000])

    untracked = get_untracked_files()
    if untracked:
        print(f"\n[untracked] {len(untracked)} files:")
        for f in untracked:
            print(f"    ? {f}")


def log_change(author, message):
    """Log a change event."""
    current = get_repo_files()
    git_diff = get_git_diff()
    untracked = get_untracked_files()

    if not SNAPSHOT_FILE.exists():
        print("[log] No baseline snapshot. Run --snapshot first.")
        return

    with open(SNAPSHOT_FILE) as f:
        baseline = json.load(f)

    baseline_files = baseline["files"]
    added = set(current.keys()) - set(baseline_files.keys())
    removed = set(baseline_files.keys()) - set(current.keys())
    modified = {
        f for f in set(current.keys()) & set(baseline_files.keys())
        if current[f]["hash"] != baseline_files[f]["hash"]
    }

    if not added and not removed and not modified and not git_diff:
        print("[log] No changes detected since last snapshot.")
        return

    entry = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "author": author,
        "message": message,
        "files_added": sorted(added),
        "files_removed": sorted(removed),
        "files_modified": sorted(modified),
        "untracked": untracked,
        "git_diff_preview": git_diff[:2000] if git_diff else None,
        "total_changes": len(added) + len(removed) + len(modified),
    }

    with open(LOG_FILE, "a") as f:
        f.write(json.dumps(entry) + "\n")

    print(f"[log] Recorded: {entry['total_changes']} file changes by {author}")
    print(f"  Message: {message}")
    if added:
        print(f"  Added: {', '.join(added)}")
    if modified:
        print(f"  Modified: {', '.join(modified)}")

    # Update snapshot after logging
    snapshot()


def show_log():
    """Show the change log."""
    if not LOG_FILE.exists():
        print("[log] No changes recorded yet.")
        return

    with open(LOG_FILE) as f:
        entries = [json.loads(line) for line in f if line.strip()]

    print(f"[log] {len(entries)} change(s) recorded:\n")
    for i, entry in enumerate(entries, 1):
        print(f"--- [{i}] {entry['timestamp']} by {entry['author']} ---")
        print(f"  Message: {entry['message']}")
        print(f"  Changes: {entry['total_changes']} files")
        if entry["files_added"]:
            print(f"  + {', '.join(entry['files_added'])}")
        if entry["files_modified"]:
            print(f"  ~ {', '.join(entry['files_modified'])}")
        if entry["files_removed"]:
            print(f"  - {', '.join(entry['files_removed'])}")
        print()


def main():
    parser = argparse.ArgumentParser(description="Track Gemini's changes in the pipeline")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--snapshot", action="store_true", help="Take baseline snapshot")
    group.add_argument("--diff", action="store_true", help="Show diff from baseline")
    group.add_argument("--log", action="store_true", help="Show change log")
    group.add_argument("--record", action="store_true", help="Record current changes")
    parser.add_argument("--author", default="gemini", help="Author name (default: gemini)")
    parser.add_argument("--message", default="", help="Description of changes")

    args = parser.parse_args()

    if args.snapshot:
        snapshot()
    elif args.diff:
        diff()
    elif args.log:
        show_log()
    elif args.record:
        if not args.message:
            print("[error] --message is required with --record")
            sys.exit(1)
        log_change(args.author, args.message)


if __name__ == "__main__":
    main()
