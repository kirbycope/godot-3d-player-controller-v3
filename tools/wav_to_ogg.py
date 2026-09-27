#!/usr/bin/env python3
"""Convert .wav files to .ogg (Ogg Vorbis) with ffmpeg and point the project at the new files.

    python tools/wav_to_ogg.py                      # every .wav under assets/, replaced in place
    python tools/wav_to_ogg.py assets/sfx           # one folder
    python tools/wav_to_ogg.py --dry-run            # list what would be converted
    python tools/wav_to_ogg.py --sync-uids          # after a headless import, put the .ogg uids into the scenes

A reference is rewritten only where the whole `res://` path of a converted file appears in a .tscn,
.tres, .gd or .json file of the project; addons/ is never touched, since every addon there is pulled
from its own repository. Godot mints a uid for an .ogg only when it imports it, so a fresh conversion
leaves the old uid in the scenes (Godot falls back to the path and warns once); run the editor or
`godot --headless --import` and then `--sync-uids` to copy each `.ogg.import`'s uid into them.
"""

from __future__ import annotations

import argparse
import re
import shutil
import subprocess
import sys
from pathlib import Path

REFERENCE_EXTENSIONS = {".tscn", ".tres", ".gd", ".json"}
SKIP_DIRS = {".git", ".godot", ".addon_cache", "addons", "build", "__pycache__"}
EXT_RESOURCE = re.compile(r"\[ext_resource\s+type=\"[^\"]+\"\s+uid=\"([^\"]+)\"\s+path=\"(res://[^\"]+)\"")


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
    except (OSError, subprocess.CalledProcessError):
        pass

    # Default fallback
    return ["-c:a", "vorbis", "-strict", "-2", "-ac", "2"]


def format_size(bytes_val: float) -> str:
    for unit in ["B", "KB", "MB", "GB"]:
        if bytes_val < 1024.0:
            return f"{bytes_val:.2f} {unit}"
        bytes_val /= 1024.0
    return f"{bytes_val:.2f} TB"


def reference_pattern(res_path: str) -> re.Pattern[str]:
    """Matches the whole `res://` path and nothing longer.

    Mapping by bare file name matched `hit.wav` inside `crit_hit.wav`; the whole path cannot. The
    lookahead stops it short of a longer path that begins the same way (`hit.wav.import`).
    """
    return re.compile(re.escape(res_path) + r"(?![A-Za-z0-9_./-])")


def imported_uid(repo_root: Path, res_path: str) -> str | None:
    """The uid Godot wrote in the file's .import, or None until it has imported the file."""
    local = repo_root / res_path.replace("res://", "")
    import_path = local.with_name(local.name + ".import")
    if not import_path.exists():
        return None
    match = re.search(r"^uid=\"([^\"]+)\"", import_path.read_text(encoding="utf-8"), re.MULTILINE)
    return match.group(1) if match else None


def update_project_references(repo_root: Path, file_mapping: dict[str, str], sync_paths: set[str]) -> int:
    """Rewrite converted paths in the project's scenes, resources, scripts and JSON, and put the uid
    Godot has minted for each path in sync_paths into the ext_resource lines that name it.

    file_mapping is old `res://` path to new; sync_paths are `res://` .ogg paths whose .ogg.import
    exists. Returns how many files changed.
    """
    if not file_mapping and not sync_paths:
        return 0

    patterns = [(reference_pattern(old), new) for old, new in file_mapping.items()]
    uids = {path: uid for path in sync_paths if (uid := imported_uid(repo_root, path))}
    modified = 0

    for file_path in sorted(repo_root.rglob("*")):
        if not file_path.is_file() or file_path.suffix not in REFERENCE_EXTENSIONS:
            continue
        if any(part in SKIP_DIRS for part in file_path.relative_to(repo_root).parts):
            continue
        try:
            content = file_path.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError) as error:
            print(f"[Warning] Could not read '{file_path}': {error}")
            continue

        updated = content
        for pattern, new in patterns:
            updated = pattern.sub(new, updated)

        if uids and file_path.suffix in {".tscn", ".tres"}:
            def uid_replacer(match: re.Match[str]) -> str:
                old_uid, res_path = match.group(1), match.group(2)
                new_uid = uids.get(res_path)
                if new_uid is None or new_uid == old_uid:
                    return match.group(0)
                return match.group(0).replace(f'uid="{old_uid}"', f'uid="{new_uid}"')

            updated = EXT_RESOURCE.sub(uid_replacer, updated)

        if updated != content:
            file_path.write_text(updated, encoding="utf-8", newline="\n")
            print(f"[Reference Updated] {file_path.relative_to(repo_root)}")
            modified += 1

    print(f"Updated references in {modified} scene/resource/script file(s).")
    return modified


def res_path(repo_root: Path, path: Path) -> str:
    return f"res://{path.relative_to(repo_root).as_posix()}"


def sync_uids(src_dir_path: Path, repo_root: Path) -> None:
    """Put the uid of every imported .ogg under src into the scenes that name it."""
    src_dir_path = src_dir_path.resolve()
    imported = {res_path(repo_root, ogg) for ogg in src_dir_path.rglob("*.ogg")
                if ogg.with_name(ogg.name + ".import").exists()}
    print(f"Found {len(imported)} imported .ogg file(s) under '{src_dir_path.relative_to(repo_root)}'.")
    update_project_references(repo_root, {}, imported)


def convert_wav_to_ogg(
    src_dir_path: Path,
    dst_dir_path: Path | None = None,
    quality: int = 6,
    in_place: bool = True,
    update_refs: bool = True,
    repo_root: Path | None = None,
    dry_run: bool = False,
) -> None:
    if not src_dir_path.exists():
        print(f"[Error] Source directory '{src_dir_path}' does not exist.")
        sys.exit(1)

    src_dir_path = src_dir_path.resolve()
    if repo_root is None:
        repo_root = Path(__file__).resolve().parent.parent

    encoder_args = get_ffmpeg_encoder()
    wav_files = sorted(src_dir_path.rglob("*.wav"))

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
    file_mapping: dict[str, str] = {}

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

                # Whole res:// paths only: a bare file name matched inside longer names.
                file_mapping[res_path(repo_root, wav_file)] = res_path(repo_root, ogg_file)

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
        # A uid is synced only for an .ogg Godot has already imported; a fresh conversion has none yet.
        update_project_references(repo_root, file_mapping, set(file_mapping.values()))

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


def main() -> None:
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
    parser.add_argument(
        "--sync-uids",
        action="store_true",
        help="Convert nothing; copy the uid of every imported .ogg under src into the scenes that name it",
    )

    args = parser.parse_args()

    if args.sync_uids:
        sync_uids(Path(args.src), repo_root)
        return

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
