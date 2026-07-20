#!/usr/bin/env python3

# Setup:
# pip install playwright
# playwright install chromium

import argparse
import importlib
import re
import shutil
import sys
import tempfile
from pathlib import Path


DEFAULT_EXTENSIONS = {".png"}
META_OPTIMIZED = "TINYIFY_OPTIMIZED"
META_METHOD = "TINYIFY_METHOD"
META_ORIGINAL_SIZE = "TINYIFY_ORIGINAL_SIZE"

Image = None
PngInfo = None


def get_pillow_modules():
	global Image, PngInfo
	if Image is None or PngInfo is None:
		try:
			from PIL import Image as pillow_image
			from PIL.PngImagePlugin import PngInfo as png_info_class
		except ImportError:
			print("[Error] Pillow is required. Install with: pip install Pillow")
			sys.exit(1)
		Image = pillow_image
		PngInfo = png_info_class
	return Image, PngInfo


def build_png_text_metadata(image, method: str, original_size: tuple[int, int]):
	_, png_info_class = get_pillow_modules()
	png_info = png_info_class()

	for key, value in image.info.items():
		if isinstance(value, str):
			png_info.add_text(key, value)

	png_info.add_text(META_OPTIMIZED, "1")
	png_info.add_text(META_METHOD, method)
	png_info.add_text(META_ORIGINAL_SIZE, f"{original_size[0]}x{original_size[1]}")
	return png_info


def write_tinyify_metadata(png_path: Path, original_size: tuple[int, int]):
	image_module, _ = get_pillow_modules()
	with image_module.open(png_path) as image:
		png_info = build_png_text_metadata(image, "tinypng", original_size)
		image.save(png_path, format="PNG", optimize=True, pnginfo=png_info)


def parse_extensions(raw_extensions: str):
	extensions = set()
	for item in raw_extensions.split(","):
		cleaned = item.strip().lower()
		if not cleaned:
			continue
		if not cleaned.startswith("."):
			cleaned = f".{cleaned}"
		extensions.add(cleaned)

	if not extensions:
		print("[Error] At least one file extension must be provided.")
		sys.exit(1)

	return extensions


def collect_files(target_path: Path, recursive: bool, extensions):
	if not target_path.exists():
		print(f"[Error] Target does not exist: {target_path}")
		sys.exit(1)

	if target_path.is_file():
		if target_path.suffix.lower() not in extensions:
			print(f"[Error] File extension not allowed: {target_path.suffix}")
			sys.exit(1)
		return [target_path.resolve()]

	if not target_path.is_dir():
		print(f"[Error] Target is neither a file nor a directory: {target_path}")
		sys.exit(1)

	matcher = "**/*" if recursive else "*"
	files = [
		path.resolve()
		for path in target_path.glob(matcher)
		if path.is_file() and path.suffix.lower() in extensions
	]
	files.sort()
	return files


def click_if_visible(locator):
	try:
		locator.first.wait_for(state="visible", timeout=2000)
		locator.first.click()
		return True
	except Exception:
		return False


def dismiss_cookie_banner(page):
	candidates = [
		page.get_by_role("button", name=re.compile(r"accept|agree|allow", re.IGNORECASE)),
		page.locator("button#onetrust-accept-btn-handler"),
	]
	for locator in candidates:
		if click_if_visible(locator):
			return


def wait_and_download(page, source_file: Path, timeout_ms: int):
	download_locators = [
		page.get_by_role("link", name=re.compile(r"download", re.IGNORECASE)),
		page.get_by_role("button", name=re.compile(r"download", re.IGNORECASE)),
		page.locator("a[href*='download']"),
	]

	first_error = None
	for locator in download_locators:
		try:
			locator.first.wait_for(state="visible", timeout=timeout_ms)
			with page.expect_download(timeout=timeout_ms) as download_info:
				locator.first.click()
			download = download_info.value
			with tempfile.NamedTemporaryFile(delete=False, suffix=source_file.suffix) as temp_file:
				temp_path = Path(temp_file.name)
			download.save_as(str(temp_path))
			shutil.move(str(temp_path), str(source_file))
			return
		except Exception as error:
			if first_error is None:
				first_error = error

	raise RuntimeError(f"Could not find/download optimized file: {first_error}")


def upload_and_download_one(page, source_file: Path, timeout_ms: int):
	image_module, _ = get_pillow_modules()
	with image_module.open(source_file) as source_image:
		original_size = source_image.size

	page.goto("https://tinypng.com/", wait_until="domcontentloaded", timeout=timeout_ms)
	dismiss_cookie_banner(page)

	upload_input = page.locator("input[type='file']").first
	upload_input.wait_for(state="attached", timeout=timeout_ms)
	upload_input.set_input_files(str(source_file))

	wait_and_download(page, source_file, timeout_ms)
	write_tinyify_metadata(source_file, original_size)


def run_web_tinyify(files, headless: bool, timeout_ms: int):
	try:
		sync_api = importlib.import_module("playwright.sync_api")
		sync_playwright = getattr(sync_api, "sync_playwright")
	except ImportError:
		print("[Error] Playwright is required. Install with: pip install playwright")
		print("[Error] Then install browser runtime with: playwright install chromium")
		sys.exit(1)

	processed = 0
	failed = 0

	with sync_playwright() as playwright:
		browser = playwright.chromium.launch(headless=headless)
		context = browser.new_context(accept_downloads=True)
		page = context.new_page()

		for file_path in files:
			try:
				print(f"Processing: {file_path}")
				upload_and_download_one(page, file_path, timeout_ms)
				print(f"Done: {file_path}")
				processed += 1
			except Exception as error:
				print(f"[Error] Failed: {file_path} -> {error}")
				failed += 1

		context.close()
		browser.close()

	print("\nTinyPNG web summary:")
	print(f"Processed: {processed}")
	if failed > 0:
		print(f"Failed: {failed}")


def main():
	parser = argparse.ArgumentParser(
		description=(
			"Upload image files to TinyPNG web UI, wait for optimization, "
			"download, and replace originals in place."
		)
	)
	parser.add_argument(
		"target",
		type=str,
		help="A single file path or a directory path",
	)
	parser.add_argument(
		"--extensions",
		type=str,
		default=",".join(sorted(DEFAULT_EXTENSIONS)),
		help="Comma-separated file extensions to include (default: .png)",
	)
	parser.add_argument(
		"--no-recursive",
		action="store_true",
		help="For directory targets, scan only top-level files",
	)
	parser.add_argument(
		"--show-browser",
		action="store_true",
		help="Show browser window while running automation",
	)
	parser.add_argument(
		"--timeout-seconds",
		type=int,
		default=120,
		help="Per-file timeout in seconds (default: 120)",
	)

	args = parser.parse_args()
	if args.timeout_seconds <= 0:
		print("[Error] --timeout-seconds must be greater than 0.")
		sys.exit(1)

	extensions = parse_extensions(args.extensions)
	target_path = Path(args.target)
	files = collect_files(target_path, recursive=not args.no_recursive, extensions=extensions)
	if not files:
		print("No matching files found.")
		return

	print(f"Found {len(files)} file(s) to process.")
	run_web_tinyify(
		files=files,
		headless=not args.show_browser,
		timeout_ms=args.timeout_seconds * 1000,
	)


if __name__ == "__main__":
	main()

# Example:
# python3 tools/tinyify_web.py assets/ambientcg_com/example.png
# python3 tools/tinyify_web.py assets --extensions .png
# python3 tools/tinyify_web.py assets --extensions .png,.jpg,.jpeg --show-browser
# python3 tools/tinyify_web.py assets --no-recursive --timeout-seconds 180

