#!/usr/bin/env python3
"""Run the two-machine Steam test suite in tests/steam: the host on this PC and the client on the Mac over SSH, at
the same time, in one lobby that only this run's id can find. Both outputs stream here with a [host] or [client]
prefix, the Mac's JUnit XML is copied back, and the exit code is non-zero when either side failed or did not report.

    python tools/steam_test.py                      # both sides
    python tools/steam_test.py --select test_07     # one scenario (GUT's -gselect, a filename substring)
    python tools/steam_test.py --role host          # one side by hand; pair it with --run-id on the other machine
    python tools/steam_test.py --windowed           # no --headless, if Steam or rendering needs a window

Before anything starts, an earlier run still going is stopped on each machine this run launches on: a Godot whose
command line carries -gdir=res://tests/steam, found by its command line on this PC and killed with taskkill, and
killed with pkill on the Mac. Left running, an old client writes the client.exit and client.xml this run reads as its
own. Whatever ends the run, a failure, Ctrl+C or the timeout, its own host and client are killed on the way out.

This PC resolves the Mac's .local name only some of the time, so the Mac is reached by IP (--mac), and the client
is not a foreground SSH command:
it is started detached under nohup with its output in .steam_test/client.log on the Mac, the launch is retried
while the name does not resolve, and the log and the exit code are polled with short SSH calls that shrug off a
failure and try again. Local only. It needs two signed-in Steam clients on two machines, so it is never wired into CI.
"""
import argparse
import os
import random
import subprocess
import sys
import threading
import time
import xml.etree.ElementTree as ElementTree

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RESULTS = os.path.join(ROOT, ".steam_test")
GODOT_PC = r"C:\Godot\godot.exe"
GODOT_MAC = "/Applications/Godot.app/Contents/MacOS/Godot"
MAC_HOST = "192.168.4.41" ## The Mac by IP: this PC's OpenSSH resolves Timothys-MacBook-Pro.local only some of the time.
MAC_USER = "timothycope"
MAC_PROJECT = "/Users/timothycope/GitHub/godot-3d-player-controller-v3"
# Engine errors are not failures here: the game's own authority handoffs (a horse mounted, the buddy picked up) and
# spawner despawns of nodes a peer has already let go log "Ignoring sync data" and "ERR_UNAUTHORIZED" bursts on
# a run that behaves; what a scenario asserts is what counts, and push_error (the lockstep's timeouts) still fails.
STEAM_GDIR = "-gdir=res://tests/steam" ## What marks a Godot running this suite, and nothing else, on either machine.
GUT_ARGS = ["-s", "addons/gut/gut_cmdln.gd", STEAM_GDIR, "-gexit", "-gfailure_error_types=gut,push_error"]
# The brackets match the same text but not themselves, so pkill passes over the SSH shell whose own command line
# carries this pattern; a bare "tests/steam" would kill that shell along with the Godot it was sent for.
MAC_STOP = "pkill -f 'gdir=res://[t]ests/steam' || true"
SSH_OPTIONS = ["-o", "BatchMode=yes", "-o", "ConnectTimeout=15", "-o", "StrictHostKeyChecking=accept-new"]
LAUNCH_RETRY_SECONDS = 150.0 ## How long the client launch keeps trying while the Mac's name does not resolve.
POLL_SECONDS = 3.0


def gut_command(godot: str, role: str, windowed: bool, select: str) -> list:
	command = [godot] + ([] if windowed else ["--headless"]) + ["--path", "."] + GUT_ARGS
	command.append("-gjunit_xml_file=res://.steam_test/%s.xml" % role)
	if select:
		command.append("-gselect=%s" % select)
	return command


def shell_quote(argument: str) -> str:
	return "'" + argument.replace("'", "'\\''") + "'"


class Mac:
	"""The Mac over SSH: every call is short, times out, and reports failure instead of raising."""

	def __init__(self, args) -> None:
		self.target = "%s@%s" % (args.mac_user, args.mac)
		self.project = args.mac_project

	def run(self, command: str, timeout: float = 30.0) -> subprocess.CompletedProcess:
		try:
			return subprocess.run(["ssh"] + SSH_OPTIONS + [self.target, command], capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=timeout)
		except subprocess.TimeoutExpired:
			return subprocess.CompletedProcess(command, 255, "", "ssh timed out")

	def scp_back(self, remote_path: str, local_path: str) -> subprocess.CompletedProcess:
		try:
			return subprocess.run(["scp"] + SSH_OPTIONS + ["%s:%s" % (self.target, remote_path), local_path], capture_output=True, text=True, timeout=60)
		except subprocess.TimeoutExpired:
			return subprocess.CompletedProcess(remote_path, 255, "", "scp timed out")


class Client:
	"""The client Godot on the Mac: launched detached, its log tailed and its exit code read by polling."""

	def __init__(self, mac: Mac, args, run_id: str) -> None:
		self.mac = mac
		self.args = args
		self.run_id = run_id
		self.offset = 0
		self.returncode = None
		self.launched = False

	def launch(self) -> bool:
		"""Starts Godot under nohup so a dropped SSH session cannot take it down; retries while the Mac is unreachable."""
		godot = " ".join(shell_quote(part) for part in gut_command(self.args.mac_godot, "client", self.args.windowed, self.args.select))
		# caffeinate keeps the Mac awake for exactly as long as Godot runs (-d display, -i idle, -s system) and is never
		# left running on its own; the owner's rule for every long SSH job there
		remote = ("cd %s && mkdir -p .steam_test && rm -f .steam_test/client.log .steam_test/client.exit .steam_test/client.xml && "
			"nohup sh -c 'STEAM_TEST_ROLE=client STEAM_TEST_ID=%s /usr/bin/caffeinate -dis %s > .steam_test/client.log 2>&1; echo $? > .steam_test/client.exit' > /dev/null 2>&1 &"
			) % (shell_quote(self.mac.project), shell_quote(self.run_id), godot)
		print("[client] Mac reached as %s (--mac %s)" % (self.mac.target, self.args.mac), flush=True)
		print("[client] ssh %s %s" % (self.mac.target, remote), flush=True)
		deadline = time.time() + LAUNCH_RETRY_SECONDS
		while True:
			result = self.mac.run(MAC_STOP) # an earlier run's client first, or its results pass for this run's
			if result.returncode == 0:
				result = self.mac.run(remote)
			if result.returncode == 0:
				self.launched = True
				return True
			print("[client] launch failed: %s" % (result.stderr.strip() or result.stdout.strip()), flush=True)
			if time.time() > deadline:
				return False
			time.sleep(10)

	def poll(self) -> None:
		"""Prints what the client has logged since the last poll and picks up its exit code once it has one."""
		result = self.mac.run("cd %s && tail -c +%d .steam_test/client.log 2>/dev/null; echo; echo __EXIT__; cat .steam_test/client.exit 2>/dev/null; true" % (shell_quote(self.mac.project), self.offset + 1))
		if result.returncode != 0:
			return
		text, _, exit_text = result.stdout.rpartition("__EXIT__")
		text = text[:-1] if text.endswith("\n") else text # the echo that separates the log from the marker
		if text:
			self.offset += len(text.encode("utf-8"))
			for line in text.splitlines():
				print("[client] %s" % line, flush=True)
		if exit_text.strip():
			self.returncode = int(exit_text.strip())

	def kill(self) -> None:
		self.mac.run(MAC_STOP)

	def fetch_xml(self) -> bool:
		"""Copies the Mac's JUnit XML back; a few tries, since the name may be down again."""
		for attempt in range(6):
			result = self.mac.scp_back("%s/.steam_test/client.xml" % self.mac.project, os.path.join(RESULTS, "client.xml"))
			if result.returncode == 0:
				return True
			print("[client] could not copy the JUnit XML back (%d/6): %s" % (attempt + 1, result.stderr.strip()), flush=True)
			time.sleep(10)
		return False


def stop_earlier_hosts() -> None:
	"""Kills every Godot on this machine still running the Steam suite; never the editor, which has no -gdir."""
	if os.name != "nt":
		subprocess.run(["pkill", "-f", "gdir=res://[t]ests/steam"], capture_output=True)
		return
	# tasklist cannot show a command line, and the image name alone would take the editor too
	query = ("Get-CimInstance Win32_Process -Filter \"Name like '%godot%'\" | "
		"Where-Object { $_.CommandLine -like '*" + STEAM_GDIR + "*' } | ForEach-Object { $_.ProcessId }")
	found = subprocess.run(["powershell", "-NoProfile", "-Command", query], capture_output=True, text=True)
	for pid in found.stdout.split():
		print("[host] stopping pid %s, left over from an earlier run" % pid, flush=True)
		subprocess.run(["taskkill", "/PID", pid, "/T", "/F"], capture_output=True)


def start_host(args, run_id: str) -> subprocess.Popen:
	env = dict(os.environ, STEAM_TEST_ROLE="host", STEAM_TEST_ID=run_id)
	command = gut_command(args.godot, "host", args.windowed, args.select)
	print("[host] " + " ".join(command), flush=True)
	return subprocess.Popen(command, cwd=ROOT, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, encoding="utf-8", errors="replace", bufsize=1)


def stream(process: subprocess.Popen, prefix: str) -> threading.Thread:
	def pump() -> None:
		for line in process.stdout:
			print("[%s] %s" % (prefix, line.rstrip("\r\n")), flush=True)

	thread = threading.Thread(target=pump, daemon=True)
	thread.start()
	return thread


def wait_all(host, client, args) -> None:
	"""Polls both sides until each has finished; once one has, the other gets a grace period before it is killed."""
	deadline = time.time() + args.timeout
	grace = None
	while True:
		if client:
			client.poll()
		host_done = host is None or host.poll() is not None
		client_done = client is None or client.returncode is not None
		if host_done and client_done:
			return
		if (host_done or client_done) and grace is None:
			grace = time.time() + args.grace
		now = time.time()
		if now > deadline or (grace is not None and now > grace):
			if host and not host_done:
				print("[host] still running after the other side finished; killing it", flush=True)
				host.kill()
			if client and not client_done:
				print("[client] still running after the other side finished; killing it", flush=True)
				client.kill()
			return
		time.sleep(POLL_SECONDS)


def totals(path: str) -> dict:
	"""Counts the test cases in a GUT JUnit file: run, failed (failure or error) and pending (skipped)."""
	if not os.path.exists(path):
		return {}
	root = ElementTree.parse(path).getroot()
	counts = {"tests": 0, "failed": 0, "pending": 0, "failures": []}
	for case in root.iter("testcase"):
		counts["tests"] += 1
		if case.find("failure") is not None or case.find("error") is not None:
			counts["failed"] += 1
			counts["failures"].append("%s.%s" % (case.get("classname", ""), case.get("name", "")))
		elif case.find("skipped") is not None:
			counts["pending"] += 1
	return counts


def report(role: str, path: str, exit_code) -> bool:
	counts = totals(path)
	if not counts:
		print("[%s] no JUnit XML at %s (Godot exit code %s)" % (role, path, exit_code), flush=True)
		return False
	print("[%s] %d tests, %d failed, %d pending (Godot exit code %s)" % (role, counts["tests"], counts["failed"], counts["pending"], exit_code), flush=True)
	for name in counts["failures"]:
		print("[%s]   FAILED %s" % (role, name), flush=True)
	return counts["failed"] == 0 and counts["tests"] > 0


def main() -> int:
	parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
	parser.add_argument("--role", choices=["host", "client", "both"], default="both", help="which side to run from here (default both: the host here, the client on the Mac)")
	parser.add_argument("--run-id", default=None, help="the run id both sides must share; made up when omitted")
	parser.add_argument("--select", default="", help="only scenarios whose filename contains this (GUT -gselect)")
	parser.add_argument("--windowed", action="store_true", help="drop --headless on both sides")
	parser.add_argument("--timeout", type=float, default=1800.0, help="seconds to allow the whole run (default 1800)")
	parser.add_argument("--grace", type=float, default=180.0, help="seconds the other side may keep running after one side has exited (default 180)")
	parser.add_argument("--godot", default=GODOT_PC, help="Godot on this PC")
	parser.add_argument("--mac", default=MAC_HOST, help="the Mac's SSH host: its IP address, since this PC resolves Timothys-MacBook-Pro.local only some of the time")
	parser.add_argument("--mac-user", default=MAC_USER)
	parser.add_argument("--mac-godot", default=GODOT_MAC, help="Godot on the Mac")
	parser.add_argument("--mac-project", default=MAC_PROJECT, help="this project's clone on the Mac")
	args = parser.parse_args()

	run_id = args.run_id or time.strftime("%Y%m%d-%H%M%S") + "-%04x" % random.randrange(0x10000)
	os.makedirs(RESULTS, exist_ok=True)
	for role in ("host", "client"):
		path = os.path.join(RESULTS, "%s.xml" % role)
		if os.path.exists(path):
			os.remove(path)
	print("run id %s" % run_id, flush=True)

	host = None
	client = None
	try:
		if args.role in ("host", "both"):
			stop_earlier_hosts()
		if args.role in ("client", "both"):
			client = Client(Mac(args), args, run_id)
			if not client.launch():
				print("[client] the Mac stayed unreachable for %.0f s; giving up" % LAUNCH_RETRY_SECONDS, flush=True)
				return 1
		if args.role in ("host", "both"):
			host = start_host(args, run_id)
			stream(host, "host")
		wait_all(host, client, args)

		ok = True
		if host:
			ok = report("host", os.path.join(RESULTS, "host.xml"), host.returncode) and ok
		if client:
			client.fetch_xml()
			ok = report("client", os.path.join(RESULTS, "client.xml"), client.returncode) and ok
		print("PASS" if ok else "FAIL", flush=True)
		return 0 if ok else 1
	finally:
		# Nothing this run started outlives it, however it ended
		if host and host.poll() is None:
			host.kill()
		if client and client.launched and client.returncode is None:
			client.kill()


if __name__ == "__main__":
	sys.exit(main())
