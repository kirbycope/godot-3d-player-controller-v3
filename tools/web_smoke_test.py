#!/usr/bin/env python3
"""Smoke-test the Web export in a real browser: serve docs/, open it in headless Chromium, get past the
click-to-start overlay and the title screen, wait for the world to load, and fail on any error the engine or the
page logs. Screenshots of each step land in scratch/web_smoke/.

    pip install playwright && playwright install chromium
    python tools/web_smoke_test.py [--port 8123] [--headed] [--timeout 180]

Exit code 0 means the world loaded with no errors; 1 means it did not, and the log says why.
"""
import argparse
import http.server
import os
import re
import socketserver
import sys
import threading
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOCS = os.path.join(ROOT, "docs")
OUT = os.path.join(ROOT, "scratch", "web_smoke")
ERROR_PATTERN = re.compile(r"\b(ERROR|SCRIPT ERROR|USER ERROR|Uncaught|RuntimeError|Aborted)\b")
WARNING_PATTERN = re.compile(r"\bWARNING\b")
IGNORED = (
	"Steam",  # GodotSteam is absent on the web and the code says so
	"godotsteam",
	"Failed to load resource: the server responded with a status of 404",  # favicon and the like
	"powerPreference",  # WebGL hints the browser does not honour
	"GPU stall due to ReadPixels",
	"A user gesture is required to request Pointer Lock",  # the synthetic click is no gesture to a headless browser
)


class Handler(http.server.SimpleHTTPRequestHandler):
	def __init__(self, *args, **kwargs):
		super().__init__(*args, directory=DOCS, **kwargs)

	def end_headers(self) -> None:
		# The shell asks for cross-origin isolation; give it the headers so it never reloads itself
		self.send_header("Cross-Origin-Opener-Policy", "same-origin")
		self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
		self.send_header("Cache-Control", "no-store")
		super().end_headers()

	def log_message(self, format: str, *args) -> None:
		pass


def serve(port: int) -> socketserver.TCPServer:
	socketserver.TCPServer.allow_reuse_address = True
	server = socketserver.ThreadingTCPServer(("127.0.0.1", port), Handler)
	threading.Thread(target=server.serve_forever, daemon=True).start()
	return server


def main() -> int:
	global DOCS
	parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
	parser.add_argument("--port", type=int, default=8123)
	parser.add_argument("--headed", action="store_true", help="show the browser")
	parser.add_argument("--timeout", type=int, default=180, help="seconds to allow for the world to load")
	parser.add_argument("--docs", default=DOCS, help="the exported folder to serve (default docs/)")
	args = parser.parse_args()
	from playwright.sync_api import sync_playwright

	DOCS = os.path.abspath(args.docs)
	os.makedirs(OUT, exist_ok=True)
	server = serve(args.port)
	url = f"http://127.0.0.1:{args.port}/index.html"
	console: list[str] = []
	errors: list[str] = []
	warnings: list[str] = []
	loaded = False
	try:
		with sync_playwright() as p:
			browser = p.chromium.launch(headless=not args.headed, args=["--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader"])
			page = browser.new_page(viewport={"width": 1280, "height": 720})

			def on_console(message) -> None:
				text = f"[{message.type}] {message.text}"
				console.append(text)
				if any(ignored in message.text for ignored in IGNORED):
					return
				# The engine writes its stderr, warnings included, as console errors: sort them by what they say
				if WARNING_PATTERN.search(message.text):
					warnings.append(text)
				elif ERROR_PATTERN.search(message.text) or (message.type == "error" and not message.text.startswith("   at:")):
					errors.append(text)

			page.on("console", on_console)
			page.on("pageerror", lambda exc: errors.append(f"[pageerror] {exc}"))
			page.on("crash", lambda: errors.append("[crash] the page crashed"))

			print(f"Opening {url}")
			page.goto(url, wait_until="load", timeout=120_000)
			canvas = page.locator("canvas#canvas")
			canvas.wait_for(state="visible", timeout=120_000)
			# The engine is up once the status overlay goes away
			page.wait_for_function("() => { const s = document.getElementById('status'); return !s || s.style.visibility === 'hidden' || getComputedStyle(s).visibility === 'hidden'; }", timeout=args.timeout * 1000)
			print("Engine started")
			page.screenshot(path=os.path.join(OUT, "1_started.png"))

			# Click to start (the web build waits for a gesture before capturing input and audio), then the title screen
			# has Single-Player focused: Enter presses it
			canvas.click(position={"x": 640, "y": 360})
			page.wait_for_timeout(1500)
			page.screenshot(path=os.path.join(OUT, "2_title.png"))
			page.keyboard.press("Enter")
			print("Single-Player pressed; waiting for the world (World.gd prints \"World ready\" once the local player has spawned)")
			started = time.time()
			while time.time() - started < args.timeout:
				page.wait_for_timeout(2000) # a Playwright wait, so console events keep arriving (a plain sleep pumps none)
				if any("World ready:" in line for line in console):
					loaded = True
					break
			page.screenshot(path=os.path.join(OUT, "3_loading.png"))
			# Give the world a moment to spawn the player and settle, then look at it
			page.wait_for_timeout(8000)
			page.screenshot(path=os.path.join(OUT, "4_world.png"))
			browser.close()
	finally:
		server.shutdown()
		with open(os.path.join(OUT, "console.log"), "w", encoding="utf-8") as log:
			log.write("\n".join(console))

	print(f"{len(console)} console lines, {len(errors)} errors, {len(warnings)} warnings (scratch/web_smoke/console.log)")
	for line in errors:
		print("  " + line)
	for line in sorted(set(warnings))[:20]:
		print("  (warning) " + line)
	if not loaded:
		print("The world did not report loading within the timeout")
		return 1
	if errors:
		return 1
	print("World loaded with no errors")
	return 0


if __name__ == "__main__":
	sys.exit(main())
