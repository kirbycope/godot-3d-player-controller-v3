#!/usr/bin/env python3
"""Tests for the parts of the two-machine Steam runner that can be tested without two machines: the command it
builds, how it finds the Mac when ssh cannot resolve the name, and how it reads a side's result from its JUnit
XML or, when that never arrived, from GUT's own console summary.

Run with:  python -m unittest tools/test_steam_test.py

The runner is imported, never run: main() needs Steam on both machines.
"""

from __future__ import annotations

import argparse
import contextlib
import io
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent))

import steam_test  # noqa: E402

PING_WINDOWS = """
Pinging Timothys-MacBook-Pro.local [192.168.4.35] with 32 bytes of data:
Reply from 192.168.4.35: bytes=32 time=3ms TTL=64
"""
PING_MAC = """PING m18.local (192.168.4.63): 56 data bytes
64 bytes from 192.168.4.63: icmp_seq=0 ttl=128 time=2.1 ms
"""
PING_UNKNOWN = "Ping request could not find host Timothys-MacBook-Pro.local. Please check the name and try again.\n"

# What GUT prints at the end of a run, colours and all, as it lands in the host's pipe and the client's log.
PASSING_CONSOLE = """\x1b[33m==============================================
\x1b[0m
Totals
------
Scripts              21
Tests                30
Passing Tests        30
Asserts             258
Time              168.053s


\x1b[32m---- All tests passed! ----
\x1b[0m
Results saved to res://.steam_test/host.xml
"""

FAILING_CONSOLE = """\x1b[4m
res://tests/steam/test_08_equipment.gd
\x1b[0m- test_a_piece_equipped_on_the_host_appears_on_the_client
\x1b[31m    [Failed]:  \x1b[0mThe other side never reached 'client_saw' within 60 s
          at line -1
\x1b[31m    [Failed]:  \x1b[0mUnexpected Errors:
    [1] <push_error>SteamTestSync: the other side never reached 'test_08_equipment/client_saw' within 60 s
          at line 12
\x1b[4m
res://tests/steam/test_19_skateboard.gd
\x1b[0m- test_the_board_is_seen_under_the_riders_feet_on_the_other_side
\x1b[33m    [Pending]:  \x1b[0mThe skateboard has no synchronizer
\x1b[4m
res://tests/steam/test_20_spells.gd
\x1b[0m- test_a_heal_channelled_on_the_host_shows_on_the_client
\x1b[31m    [Failed]:  \x1b[0mThe other side never reached 'client_saw_channel' within 60 s
          at line -1

Totals
------
Scripts              20
Tests                30
Passing Tests        24
Failing Tests         2
Risky/Pending         4
Asserts           208/216
Time              581.347s


\x1b[31m---- 2 failing tests ----
\x1b[0m
[steam_test] host: left lobby 109775241336728767 and closed the peer
"""

ABORTED_CONSOLE = """[steam_test] client: joining lobby 109775241336728767
\x1b[31mSTEAM TEST ABORT (client): the host's session_start never arrived within 120 s\x1b[0m
[steam_test] client: left lobby 109775241336728767 and closed the peer
"""

PASSING_XML = """<?xml version="1.0" encoding="UTF-8"?>
<testsuites name="GutTests" failures="0" tests="2">
  <testsuite name="res://tests/steam/test_01_lobby.gd" tests="2" failures="0" skipped="0">
    <testcase name="test_both_sides_join" classname="res://tests/steam/test_01_lobby.gd" status="pass"/>
    <testcase name="test_both_sides_leave" classname="res://tests/steam/test_01_lobby.gd" status="pass"/>
  </testsuite>
</testsuites>
"""


def mac_args(host: str = steam_test.MAC_HOST) -> argparse.Namespace:
    return argparse.Namespace(mac=host, mac_user="timothycope", mac_project="/Users/timothycope/GitHub/project")


def completed(returncode: int, stderr: str = "") -> subprocess.CompletedProcess:
    return subprocess.CompletedProcess([], returncode, "", stderr)


class GutCommand(unittest.TestCase):
    def test_the_command_names_the_suite_the_junit_file_and_the_selection(self) -> None:
        command = steam_test.gut_command("godot", "client", windowed=False, select="test_07")
        self.assertEqual(command[:4], ["godot", "--headless", "--path", "."])
        self.assertIn("-gdir=res://tests/steam", command)
        self.assertIn("-gjunit_xml_file=res://.steam_test/client.xml", command)
        self.assertEqual(command[-1], "-gselect=test_07")

    def test_windowed_drops_headless_and_no_selection_adds_nothing(self) -> None:
        command = steam_test.gut_command("godot", "host", windowed=True, select="")
        self.assertNotIn("--headless", command)
        self.assertFalse(any(part.startswith("-gselect") for part in command))

    def test_shell_quote_survives_a_single_quote(self) -> None:
        self.assertEqual(steam_test.shell_quote("it's"), "'it'\\''s'")


class PingAddress(unittest.TestCase):
    def test_the_address_windows_ping_prints_in_brackets(self) -> None:
        self.assertEqual(steam_test.ping_address(PING_WINDOWS), "192.168.4.35")

    def test_the_address_a_mac_ping_prints_in_parentheses(self) -> None:
        self.assertEqual(steam_test.ping_address(PING_MAC), "192.168.4.63")

    def test_a_name_ping_cannot_find_gives_none(self) -> None:
        self.assertIsNone(steam_test.ping_address(PING_UNKNOWN))
        self.assertIsNone(steam_test.ping_address(""))


class ResolvingTheMac(unittest.TestCase):
    """M19: the runner defaulted to an address the Mac no longer had and retried against it for 150 s."""

    def test_the_default_is_the_name_not_an_address(self) -> None:
        self.assertEqual(steam_test.MAC_HOST, "Timothys-MacBook-Pro.local")

    def test_a_name_ssh_cannot_resolve_is_swapped_for_the_address_ping_finds(self) -> None:
        mac = steam_test.Mac(mac_args())
        unresolved = completed(255, "ssh: Could not resolve hostname Timothys-MacBook-Pro.local: Name or service not known")
        with mock.patch.object(steam_test.Mac, "run", side_effect=[unresolved, completed(0)]) as run, \
                mock.patch.object(steam_test, "ping_output", return_value=PING_WINDOWS) as ping, \
                contextlib.redirect_stdout(io.StringIO()):
            self.assertTrue(mac.resolve())
        ping.assert_called_once_with("Timothys-MacBook-Pro.local")
        self.assertEqual(mac.host, "192.168.4.35")
        self.assertEqual(mac.target, "timothycope@192.168.4.35")
        self.assertEqual(run.call_count, 2, "checked once by name, once by address")

    def test_a_name_that_resolves_is_kept_and_ping_is_never_asked(self) -> None:
        mac = steam_test.Mac(mac_args())
        with mock.patch.object(steam_test.Mac, "run", return_value=completed(0)), \
                mock.patch.object(steam_test, "ping_output") as ping:
            self.assertTrue(mac.resolve())
        ping.assert_not_called()
        self.assertEqual(mac.host, "Timothys-MacBook-Pro.local")

    def test_a_failure_that_is_not_about_the_name_changes_nothing(self) -> None:
        # The Mac is asleep or refusing: the launch loop's retries are the answer, not a new address.
        mac = steam_test.Mac(mac_args("192.168.4.35"))
        with mock.patch.object(steam_test.Mac, "run", return_value=completed(255, "ssh: connect to host 192.168.4.35 port 22: Connection timed out")), \
                mock.patch.object(steam_test, "ping_output") as ping:
            self.assertFalse(mac.resolve())
        ping.assert_not_called()
        self.assertEqual(mac.host, "192.168.4.35", "--mac stays what it was given")

    def test_a_name_neither_ssh_nor_ping_can_resolve_is_reported_and_kept(self) -> None:
        mac = steam_test.Mac(mac_args())
        out = io.StringIO()
        with mock.patch.object(steam_test.Mac, "run", return_value=completed(255, "ssh: Could not resolve hostname")), \
                mock.patch.object(steam_test, "ping_output", return_value=PING_UNKNOWN), \
                contextlib.redirect_stdout(out):
            self.assertFalse(mac.resolve())
        self.assertIn("ping found no address", out.getvalue())
        self.assertEqual(mac.host, "Timothys-MacBook-Pro.local")


class ConsoleTotals(unittest.TestCase):
    """M26: the host died at exit before GUT wrote host.xml, and the runner counted a side it had watched pass
    as one that never reported. GUT had already printed its Totals; those are what the runner reads."""

    def test_a_passing_run_is_read_from_its_totals_block(self) -> None:
        self.assertEqual(steam_test.console_totals(PASSING_CONSOLE), {"tests": 30, "failed": 0, "pending": 0, "failures": []})

    def test_a_failing_run_gives_its_counts_and_the_failed_tests_by_name(self) -> None:
        counts = steam_test.console_totals(FAILING_CONSOLE)
        self.assertEqual((counts["tests"], counts["failed"], counts["pending"]), (30, 2, 4))
        self.assertEqual(counts["failures"], [
            "res://tests/steam/test_08_equipment.gd.test_a_piece_equipped_on_the_host_appears_on_the_client",
            "res://tests/steam/test_20_spells.gd.test_a_heal_channelled_on_the_host_shows_on_the_client",
        ], "each failed test once, and the pending one not at all")

    def test_output_with_no_totals_block_is_no_result(self) -> None:
        self.assertEqual(steam_test.console_totals(ABORTED_CONSOLE), {})
        self.assertEqual(steam_test.console_totals(""), {})

    def test_the_abort_line_is_found_without_its_colour_codes(self) -> None:
        self.assertEqual(steam_test.abort_lines(ABORTED_CONSOLE),
                         ["STEAM TEST ABORT (client): the host's session_start never arrived within 120 s"])
        self.assertEqual(steam_test.abort_lines(PASSING_CONSOLE), [])


class Reporting(unittest.TestCase):
    def setUp(self) -> None:
        self._temp = tempfile.TemporaryDirectory()
        self.addCleanup(self._temp.cleanup)
        self.xml = str(Path(self._temp.name) / "host.xml")

    def report(self, exit_code: int | None, console: str) -> tuple[bool, str]:
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            ok = steam_test.report("host", self.xml, exit_code, console)
        return ok, out.getvalue()

    def test_a_junit_file_is_what_counts_when_it_is_there(self) -> None:
        Path(self.xml).write_text(PASSING_XML)
        ok, out = self.report(0, "")
        self.assertTrue(ok)
        self.assertIn("[host] 2 tests, 0 failed, 0 pending (Godot exit code 0)", out)

    def test_a_missing_junit_file_is_read_from_the_console_and_still_fails(self) -> None:
        ok, out = self.report(3221225477, PASSING_CONSOLE)
        self.assertFalse(ok, "the file missing is itself the thing to look into")
        self.assertIn("[host] 30 tests, 0 failed, 0 pending (Godot exit code 3221225477; from the console, no JUnit XML at", out)

    def test_console_failures_are_listed_by_name(self) -> None:
        ok, out = self.report(1, FAILING_CONSOLE)
        self.assertFalse(ok)
        self.assertIn("[host] 30 tests, 2 failed, 4 pending", out)
        self.assertIn("[host]   FAILED res://tests/steam/test_08_equipment.gd.test_a_piece_equipped_on_the_host_appears_on_the_client", out)

    def test_an_abort_line_is_repeated_in_the_summary(self) -> None:
        ok, out = self.report(1, ABORTED_CONSOLE)
        self.assertFalse(ok)
        self.assertIn("[host] STEAM TEST ABORT (client): the host's session_start never arrived within 120 s", out)
        self.assertIn("no JUnit XML at", out)
        self.assertIn("no Totals in its console", out)


if __name__ == "__main__":
    unittest.main()
