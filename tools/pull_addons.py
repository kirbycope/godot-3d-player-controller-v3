#!/usr/bin/env python3
"""
Pull addon changes from external repositories into this project.
Removes the target addon directory first to ensure deleted files in upstream are properly cleaned up.
"""

import argparse
import os
import shutil
import stat
import sys
from pathlib import Path

# Mapping of addon name -> default source directory
DEFAULT_SOURCES = {
    "date_and_time": Path(r"C:\GitHub\date-and-time\addons\date_and_time"),
    "radi_ot": Path(r"C:\GitHub\radi-ot\addons\radi_ot"),
    "weather_fx": Path(r"C:\GitHub\weather-fx\addons\weather_fx"),
}


def handle_remove_readonly(func, path, exc_info):
    """Clear the readonly bit and retry deletion (handles Windows permission issues)."""
    try:
        os.chmod(path, stat.S_IWRITE)
        func(path)
    except Exception as exc:
        print(f"  [Error] Failed to remove {path}: {exc}", file=sys.stderr)


def remove_directory(target_path: Path, dry_run: bool = False) -> bool:
    """Removes a directory tree cleanly."""
    if not target_path.exists():
        return True

    if dry_run:
        print(f"  [Dry-run] Would delete: {target_path}")
        return True

    try:
        shutil.rmtree(target_path, onerror=handle_remove_readonly)
        print(f"  [Deleted] Removed old addon directory: {target_path}")
        return True
    except Exception as e:
        print(f"  [Error] Failed to delete {target_path}: {e}", file=sys.stderr)
        return False


def copy_directory(source_path: Path, target_path: Path, dry_run: bool = False) -> int:
    """Copies source directory to target destination. Returns count of copied files."""
    if dry_run:
        count = sum(1 for p in source_path.rglob("*") if p.is_file())
        print(f"  [Dry-run] Would copy {count} files from {source_path} -> {target_path}")
        return count

    target_path.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(source_path, target_path)
    count = sum(1 for p in target_path.rglob("*") if p.is_file())
    print(f"  [Copied] {count} files from {source_path} -> {target_path}")
    return count


def pull_addons(selected_addons: list[str] | None = None, github_root: Path | None = None, dry_run: bool = False) -> int:
    script_dir = Path(__file__).resolve().parent
    project_root = script_dir.parent
    project_addons_dir = project_root / "addons"

    sources = dict(DEFAULT_SOURCES)
    if github_root:
        # Override source paths with custom root directory if provided
        sources = {
            "date_and_time": github_root / "date-and-time" / "addons" / "date_and_time",
            "radi_ot": github_root / "radi-ot" / "addons" / "radi_ot",
            "weather_fx": github_root / "weather-fx" / "addons" / "weather_fx",
        }

    addons_to_pull = selected_addons if selected_addons else list(sources.keys())
    success_count = 0
    failure_count = 0

    print("=" * 60)
    print(f"Pulling addons into: {project_addons_dir}")
    if dry_run:
        print("MODE: DRY RUN (no files will be deleted or copied)")
    print("=" * 60)

    for addon_name in addons_to_pull:
        if addon_name not in sources:
            print(f"\n[Unknown Addon] '{addon_name}'. Available: {', '.join(sources.keys())}")
            failure_count += 1
            continue

        src = sources[addon_name]
        dst = project_addons_dir / addon_name

        print(f"\nProcessing '{addon_name}':")
        print(f"  Source:      {src}")
        print(f"  Destination: {dst}")

        if not src.exists() or not src.is_dir():
            print(f"  [Error] Source path not found or not a directory: {src}", file=sys.stderr)
            failure_count += 1
            continue

        # 1. Remove destination
        if dst.exists():
            if not remove_directory(dst, dry_run=dry_run):
                failure_count += 1
                continue

        # 2. Copy source to destination
        try:
            copy_directory(src, dst, dry_run=dry_run)
            success_count += 1
        except Exception as e:
            print(f"  [Error] Failed to copy {src} to {dst}: {e}", file=sys.stderr)
            failure_count += 1

    print("\n" + "=" * 60)
    print(f"Summary: {success_count} succeeded, {failure_count} failed.")
    print("=" * 60)

    return 0 if failure_count == 0 else 1


def main():
    parser = argparse.ArgumentParser(
        description="Pull and update Godot addons from local source repositories with clean removal."
    )
    parser.add_argument(
        "--addon",
        "-a",
        action="append",
        choices=list(DEFAULT_SOURCES.keys()),
        help="Specify one or more specific addon(s) to pull (default: all).",
    )
    parser.add_argument(
        "--github-root",
        "-g",
        type=Path,
        help="Optional custom root folder containing the repos (default: C:\\GitHub).",
    )
    parser.add_argument(
        "--dry-run",
        "-n",
        action="store_true",
        help="Show actions that would be performed without modifying files.",
    )

    args = parser.parse_args()
    sys.exit(pull_addons(selected_addons=args.addon, github_root=args.github_root, dry_run=args.dry_run))


if __name__ == "__main__":
    main()


# python tools/pull_addons.py
# python tools/pull_addons.py --dry-run
# python tools/pull_addons.py --addon weather_fx
# python tools/pull_addons.py --github-root <path>
