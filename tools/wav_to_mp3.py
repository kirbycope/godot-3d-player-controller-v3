#!/usr/bin/env python3
import sys
import subprocess
import shutil
from pathlib import Path
import argparse

def convert_wav_to_mp3(src_dir_path: Path, dst_dir_path: Path, overwrite: bool = True):
    if not src_dir_path.exists():
        print(f"[Error] Source directory '{src_dir_path}' does not exist.")
        sys.exit(1)

    if not shutil.which("ffmpeg"):
        print("[Error] 'ffmpeg' executable not found on PATH. Please install ffmpeg.")
        sys.exit(1)

    src_dir_path = src_dir_path.resolve()
    dst_dir_path = dst_dir_path.resolve()

    # Find all .wav files recursively
    wav_files = list(src_dir_path.rglob("*.wav"))
    
    if not wav_files:
        print(f"No .wav files found in '{src_dir_path}'.")
        return

    print(f"Found {len(wav_files)} .wav files to convert.")

    success_count = 0
    fail_count = 0

    for wav_file in wav_files:
        # Avoid processing files already inside destination (e.g. if dst is inside src)
        try:
            wav_file.relative_to(dst_dir_path)
            continue
        except ValueError:
            pass

        # Get relative path to rebuild in dst
        rel_path = wav_file.relative_to(src_dir_path)
        # Target mp3 file path
        mp3_file = dst_dir_path / rel_path.with_suffix(".mp3")

        # Create target directories if necessary
        mp3_file.parent.mkdir(parents=True, exist_ok=True)

        if mp3_file.exists() and not overwrite:
            print(f"Skipping (already exists): {mp3_file}")
            continue

        print(f"Converting: {rel_path} -> {mp3_file.relative_to(dst_dir_path)}")

        # Build ffmpeg command
        cmd = [
            "ffmpeg", "-y", "-loglevel", "error",
            "-i", str(wav_file),
            "-codec:a", "libmp3lame",
            "-qscale:a", "2",
            str(mp3_file)
        ]

        try:
            subprocess.run(cmd, check=True)
            success_count += 1
        except subprocess.CalledProcessError as e:
            print(f"[Error] Failed to convert '{wav_file.name}': {e}")
            fail_count += 1

    print(f"\nConversion finished:")
    print(f"Successfully converted: {success_count}")
    if fail_count > 0:
        print(f"Failed: {fail_count}")

def main():
    parser = argparse.ArgumentParser(description="Convert WAV files to MP3 recursively.")
    parser.add_argument("src", type=str, help="Source directory containing .wav files")
    parser.add_argument("dst", type=str, help="Destination directory for .mp3 files")
    parser.add_argument("--no-overwrite", action="store_true", help="Do not overwrite existing .mp3 files")

    args = parser.parse_args()

    src_path = Path(args.src)
    dst_path = Path(args.dst)

    convert_wav_to_mp3(src_path, dst_path, overwrite=not args.no_overwrite)

if __name__ == "__main__":
    main()

# python3 tools/wav_to_mp3.py addons/3d_player_controller/assets/epicstockmedia/game_footsteps addons/3d_player_controller/assets/epicstockmedia/game_footsteps/mp3
