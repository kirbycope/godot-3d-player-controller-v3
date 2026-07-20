#!/usr/bin/env python3
import argparse
import importlib
import os
import sys
from pathlib import Path

Image = None
tinify = None


def get_pillow_image_module():
    global Image
    if Image is None:
        try:
            from PIL import Image as pillow_image
        except ImportError:
            print("[Error] Pillow is required. Install it with: pip install Pillow")
            sys.exit(1)
        Image = pillow_image
    return Image


def get_tinify_module(api_key: str, strict: bool):
    global tinify
    if tinify is None:
        try:
            tinify_module = importlib.import_module("tinify")
        except ImportError:
            message = "[Error] tinify is required for TinyPNG mode. Install with: pip install tinify"
            if strict:
                print(message)
                sys.exit(1)
            print(f"[Warning] {message} Falling back to local Pillow optimization.")
            return None
        tinify = tinify_module

    tinify.key = api_key
    return tinify


def load_api_key(project_root: Path):
    key = os.getenv("TINY_PNG_API_KEY") or os.getenv("TINYPNG_API_KEY")
    if key:
        return key.strip()

    env_path = project_root / ".env"
    if not env_path.exists():
        return None

    try:
        with env_path.open("r", encoding="utf-8") as env_file:
            for raw_line in env_file:
                line = raw_line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue

                name, value = line.split("=", 1)
                var_name = name.strip()
                if var_name not in {"TINY_PNG_API_KEY", "TINYPNG_API_KEY"}:
                    continue

                cleaned = value.strip().strip('"').strip("'")
                if cleaned:
                    return cleaned
    except OSError as error:
        print(f"[Warning] Could not read .env file: {error}")

    return None


def iter_png_files(src_dir_path: Path):
    for file_path in src_dir_path.rglob("*"):
        if file_path.is_file() and file_path.suffix.lower() == ".png":
            yield file_path


def optimize_pngs_in_place(root_dir_path: Path, max_size: int, engine: str, api_key):
    image_module = get_pillow_image_module()
    use_tinypng = engine == "tinypng"

    if engine == "auto":
        use_tinypng = api_key is not None

    tinify_module = None
    if use_tinypng:
        strict = engine == "tinypng"
        if not api_key:
            print("[Error] TinyPNG mode requested but no API key was found.")
            print("Set TINY_PNG_API_KEY in environment or .env.")
            sys.exit(1)

        tinify_module = get_tinify_module(api_key, strict=strict)
        if tinify_module is None:
            use_tinypng = False

    if not root_dir_path.exists() or not root_dir_path.is_dir():
        print(f"[Error] Root directory '{root_dir_path}' does not exist or is not a directory.")
        sys.exit(1)

    root_dir_path = root_dir_path.resolve()

    png_files = list(iter_png_files(root_dir_path))
    if not png_files:
        print(f"No .png files found in '{root_dir_path}'.")
        return

    if use_tinypng:
        print("Engine: TinyPNG API")
    else:
        print("Engine: Local Pillow")
    print(f"Found {len(png_files)} .png files to optimize.")

    processed_count = 0
    resized_count = 0
    fail_count = 0

    for png_file in png_files:
        rel_path = png_file.relative_to(root_dir_path)

        try:
            with image_module.open(png_file) as image:
                original_width, original_height = image.size
                largest_edge = max(original_width, original_height)

                if use_tinypng:
                    source = tinify_module.from_file(str(png_file))
                    if largest_edge > max_size:
                        resized = source.resize(
                            method="fit",
                            width=max_size,
                            height=max_size,
                        )
                        resized.to_file(str(png_file))
                        scale_ratio = max_size / float(largest_edge)
                        new_width = max(1, int(round(original_width * scale_ratio)))
                        new_height = max(1, int(round(original_height * scale_ratio)))
                        resized_count += 1
                        print(
                            f"Resized: {rel_path} "
                            f"({original_width}x{original_height} -> {new_width}x{new_height})"
                        )
                    else:
                        source.to_file(str(png_file))
                        print(f"Optimized: {rel_path} ({original_width}x{original_height})")
                else:
                    if largest_edge > max_size:
                        scale_ratio = max_size / float(largest_edge)
                        new_width = max(1, int(round(original_width * scale_ratio)))
                        new_height = max(1, int(round(original_height * scale_ratio)))
                        resized_image = image.resize(
                            (new_width, new_height),
                            image_module.Resampling.LANCZOS,
                        )
                        resized_image.save(png_file, format="PNG", optimize=True)
                        resized_count += 1
                        print(
                            f"Resized: {rel_path} "
                            f"({original_width}x{original_height} -> {new_width}x{new_height})"
                        )
                    else:
                        image.save(png_file, format="PNG", optimize=True)
                        print(f"Optimized: {rel_path} ({original_width}x{original_height})")

            processed_count += 1
        except OSError as error:
            print(f"[Error] Failed to process '{rel_path}': {error}")
            fail_count += 1
        except Exception as error:
            tiny_errors = {
                "AccountError",
                "ClientError",
                "ServerError",
                "ConnectionError",
            }
            if use_tinypng and type(error).__name__ in tiny_errors:
                print(f"[Error] TinyPNG failed for '{rel_path}': {error}")
            else:
                print(f"[Error] Unexpected failure for '{rel_path}': {error}")
            fail_count += 1

    print("\nOptimization finished:")
    print(f"Processed: {processed_count}")
    print(f"Resized: {resized_count}")
    if fail_count > 0:
        print(f"Failed: {fail_count}")


def main():
    project_root = Path(__file__).resolve().parent.parent

    parser = argparse.ArgumentParser(
        description=(
            "Optimize PNG images recursively in place and cap image dimensions. "
            "Defaults to repository root."
        )
    )
    parser.add_argument(
        "root",
        type=str,
        nargs="?",
        default=str(project_root),
        help="Root directory to scan recursively (default: repository root)",
    )
    parser.add_argument(
        "--max-size",
        type=int,
        default=1024,
        help="Maximum size in pixels for the largest image edge (default: 1024)",
    )
    parser.add_argument(
        "--engine",
        choices=["auto", "local", "tinypng"],
        default="auto",
        help="Optimization engine: auto, local, or tinypng (default: auto)",
    )
    args = parser.parse_args()

    if args.max_size <= 0:
        print("[Error] --max-size must be greater than 0.")
        sys.exit(1)

    root_path = Path(args.root)
    api_key = load_api_key(project_root)
    optimize_pngs_in_place(
        root_path,
        max_size=args.max_size,
        engine=args.engine,
        api_key=api_key,
    )


if __name__ == "__main__":
    main()

# Example:
# pip install Pillow tinify
# python3 tools/optimize_png.py
# python3 tools/optimize_png.py . --max-size 1024
# python3 tools/optimize_png.py --engine tinypng
