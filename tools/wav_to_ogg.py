#!/usr/bin/env python3
"""
wav_to_ogg.py

Recursively converts .wav audio files to .ogg (Ogg Vorbis) format using ffmpeg.
Optionally replaces .wav with .ogg in-place, cleans up obsolete .import / .DS_Store files,
and updates scene (.tscn), resource (.tres), and script (.gd) file references.
"""

from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Dict, List, Optional


def get_ffmpeg_encoder() -> list[str]:
    """Determine the best available Vorbis encoder for ffmpeg."""
    if not shutil.which("ffmpeg"):
        print("[Error] 'ffmpeg' executable not found on PATH. Please install ffmpeg.")
        sys.exit(1)

    try:
        res = subprocess.run(
            ["ffmpeg", "-encoders"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            check=True,
        )
        if "libvorbis" in res.stdout:
            return ["-c:a", "libvorbis"]
        elif "vorbis" in res.stdout:
            return ["-c:a", "vorbis", "-strict", "-2", "-ac", "2"]
    except Exception:
        pass

    # Default fallback
    return ["-c:a", "vorbis", "-strict", "-2", "-ac", "2"]


def format_size(bytes_val: int) -> str:
    for unit in ["B", "KB", "MB", "GB"]:
        if bytes_val < 1024.0:
            return f"{bytes_val:.2f} {unit}"
        bytes_val /= 1024.0
    return f"{bytes_val:.2f} TB"


def update_project_references(repo_root: Path, file_mapping: dict[str, str]):
    """
    Updates occurrences of converted .wav paths to .ogg in .tscn, .tres, and .gd files,
    and updates any resource UIDs if .import files are present.
    file_mapping maps relative res:// path (or filename) from old to new.
    """
    if not file_mapping:
        return

    extensions = {".tscn", ".tres", ".gd", ".json"}
    modified_files = 0
    uid_pattern = re.compile(r"\[ext_resource\s+type=\"[^\"]+\"\s+uid=\"([^\"]+)\"\s+path=\"(res://[^\"]+)\"")

    for file_path in repo_root.rglob("*"):
        if not file_path.is_file() or file_path.suffix not in extensions:
            continue
        # Skip .godot and .git directories
        if ".godot" in file_path.parts or ".git" in file_path.parts:
            continue

        try:
            content = file_path.read_text(encoding="utf-8")
            changed = False
            for old_str, new_str in file_mapping.items():
                if old_str in content:
                    content = content.replace(old_str, new_str)
                    changed = True

            # Sync UIDs from .import files if present
            if file_path.suffix in {".tscn", ".tres"}:
                def uid_replacer(match):
                    old_uid = match.group(1)
                    res_path = match.group(2)
                    local_path = repo_root / res_path.replace("res://", "")
                    import_path = Path(str(local_path) + ".import")
                    if import_path.exists():
                        try:
                            import_content = import_path.read_text(encoding="utf-8")
                            m = re.search(r"uid=\"([^\"]+)\"", import_content)
                            if m and m.group(1) != old_uid:
                                return match.group(0).replace(old_uid, m.group(1))
                        except Exception:
                            pass
                    return match.group(0)

                new_content = uid_pattern.sub(uid_replacer, content)
                if new_content != content:
                    content = new_content
                    changed = True

            if changed:
                file_path.write_text(content, encoding="utf-8")
                print(f"[Reference Updated] {file_path.relative_to(repo_root)}")
                modified_files += 1
        except Exception as e:
            print(f"[Warning] Could not process file '{file_path}': {e}")

    print(f"Updated references in {modified_files} scene/resource/script file(s).")


def convert_wav_to_ogg(
    src_dir_path: Path,
    dst_dir_path: Path | None = None,
    quality: int = 6,
    in_place: bool = True,
    update_refs: bool = True,
    repo_root: Path | None = None,
    dry_run: bool = False,
):
    if not src_dir_path.exists():
        print(f"[Error] Source directory '{src_dir_path}' does not exist.")
        sys.exit(1)

    src_dir_path = src_dir_path.resolve()
    if repo_root is None:
        repo_root = Path(__file__).resolve().parent.parent

    encoder_args = get_ffmpeg_encoder()
    wav_files = sorted(list(src_dir_path.rglob("*.wav")))

    if not wav_files:
        print(f"No .wav files found in '{src_dir_path}'.")
        return

    print(f"Found {len(wav_files)} .wav file(s) to convert.")
    print(f"Encoder: {' '.join(encoder_args)} (Quality: {quality})")
    if dry_run:
        print("[DRY RUN MODE] No changes will be written.")

    total_wav_size = sum(f.stat().st_size for f in wav_files)
    total_ogg_size = 0

    success_count = 0
    fail_count = 0
    file_mapping = {}

    for wav_file in wav_files:
        if in_place or dst_dir_path is None:
            ogg_file = wav_file.with_suffix(".ogg")
        else:
            rel_path = wav_file.relative_to(src_dir_path)
            ogg_file = (dst_dir_path / rel_path).with_suffix(".ogg")
            ogg_file.parent.mkdir(parents=True, exist_ok=True)

        rel_wav = wav_file.relative_to(repo_root)
        rel_ogg = ogg_file.relative_to(repo_root)

        print(f"Converting: {rel_wav} -> {rel_ogg}")

        if dry_run:
            success_count += 1
            continue

        cmd = [
            "ffmpeg",
            "-y",
            "-loglevel",
            "error",
            "-i",
            str(wav_file),
            *encoder_args,
            "-q:a",
            str(quality),
            str(ogg_file),
        ]

        try:
            subprocess.run(cmd, check=True)
            if ogg_file.exists() and ogg_file.stat().st_size > 0:
                ogg_size = ogg_file.stat().st_size
                total_ogg_size += ogg_size
                success_count += 1

                # Record mapping for references
                res_old = f"res://{rel_wav.as_posix()}"
                res_new = f"res://{rel_ogg.as_posix()}"
                file_mapping[res_old] = res_new
                file_mapping[wav_file.name] = ogg_file.name

                if in_place:
                    wav_file.unlink()
                    wav_import = wav_file.with_name(wav_file.name + ".import")
                    if wav_import.exists():
                        wav_import.unlink()
            else:
                print(f"[Error] Output file missing or empty: {ogg_file}")
                fail_count += 1
        except subprocess.CalledProcessError as e:
            print(f"[Error] Failed converting '{wav_file.name}': {e}")
            fail_count += 1

    # Remove lingering .DS_Store files in src_dir_path
    if not dry_run and in_place:
        for ds in src_dir_path.rglob(".DS_Store"):
            try:
                ds.unlink()
            except OSError:
                pass

    if update_refs and file_mapping and not dry_run:
        print("\nUpdating project references...")
        update_project_references(repo_root, file_mapping)

    print("\n--- Summary ---")
    print(f"Successfully converted: {success_count} file(s)")
    if fail_count > 0:
        print(f"Failed conversions:     {fail_count} file(s)")
    print(f"Original WAV size:      {format_size(total_wav_size)}")
    if not dry_run and total_ogg_size > 0:
        print(f"New OGG size:           {format_size(total_ogg_size)}")
        saved_bytes = total_wav_size - total_ogg_size
        pct = (saved_bytes / total_wav_size) * 100 if total_wav_size > 0 else 0
        print(f"Space saved:            {format_size(saved_bytes)} ({pct:.1f}% reduction)")


def main():
    repo_root = Path(__file__).resolve().parent.parent

    parser = argparse.ArgumentParser(
        description="Recursively convert WAV files to OGG Vorbis and update scene references."
    )
    parser.add_argument(
        "src",
        type=str,
        nargs="?",
        default=str(repo_root / "assets"),
        help="Source directory containing .wav files (default: assets/)",
    )
    parser.add_argument(
        "--dst",
        type=str,
        default=None,
        help="Destination directory (if not specified, performs in-place replacement)",
    )
    parser.add_argument(
        "-q",
        "--quality",
        type=int,
        default=6,
        help="Vorbis VBR quality level 0-10 (default: 6)",
    )
    parser.add_argument(
        "--no-in-place",
        action="store_true",
        help="Keep original .wav files instead of replacing them in-place",
    )
    parser.add_argument(
        "--no-update-refs",
        action="store_true",
        help="Do not scan and update references in .tscn/.tres/.gd files",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="List files that would be converted without making changes",
    )

    args = parser.parse_args()

    in_place = not args.no_in_place and args.dst is None
    update_refs = not args.no_update_refs

    convert_wav_to_ogg(
        src_dir_path=Path(args.src),
        dst_dir_path=Path(args.dst) if args.dst else None,
        quality=args.quality,
        in_place=in_place,
        update_refs=update_refs,
        repo_root=repo_root,
        dry_run=args.dry_run,
    )


if __name__ == "__main__":
    main()
