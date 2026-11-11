#!/usr/bin/env python3
"""Regression tests for dogfood timing, timeout handling, and summaries."""
from __future__ import annotations

import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


HERE = Path(__file__).resolve().parent
TIMER = HERE / "timed_run.py"
SUMMARY = HERE / "dogfood.py"


class ReportingTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory(prefix="gdt-dogfood-reporting-")
        self.root = Path(self.temp.name)

    def tearDown(self) -> None:
        self.temp.cleanup()

    def timed(self, timeout: str, command: list[str], name: str = "run") -> tuple[subprocess.CompletedProcess, Path]:
        path = self.root / f"{name}.timing.json"
        result = subprocess.run(
            [sys.executable, str(TIMER), str(path), timeout, *command],
            capture_output=True, text=True, timeout=5, check=False,
        )
        return result, path

    def test_success_failure_and_missing_executable(self) -> None:
        for code in (0, 7, 124):
            with self.subTest(code=code):
                result, path = self.timed("2", [sys.executable, "-c", f"print('hello'); exit({code})"], str(code))
                self.assertEqual(result.returncode, code, result.stderr)
                self.assertIn("hello", result.stdout)
                data = json.loads(path.read_text(encoding="utf-8"))
                self.assertEqual(data["exit_code"], code)
                self.assertFalse(data["timed_out"])
                self.assertEqual(data["timeout_seconds"], 2)
                self.assertGreaterEqual(data["elapsed_ms"], 0)
        result, path = self.timed("2", [str(self.root / "missing-executable")], "missing")
        self.assertEqual(result.returncode, 127, result.stderr)
        self.assertEqual(json.loads(path.read_text(encoding="utf-8"))["exit_code"], 127)
        self.assertIn("Could not start command", result.stderr)

    def test_timeout_is_bounded_and_recorded(self) -> None:
        result, path = self.timed("0.05", [sys.executable, "-c", "import time; time.sleep(2)"])
        self.assertEqual(result.returncode, 124, result.stderr)
        data = json.loads(path.read_text(encoding="utf-8"))
        self.assertEqual(data["exit_code"], 124)
        self.assertTrue(data["timed_out"])
        self.assertGreaterEqual(data["elapsed_ms"], 40)
        self.assertIn("timed out", result.stderr)

    def test_invalid_timeout_is_rejected(self) -> None:
        for value in ("0", "-1", "nan", "inf", "1e300", "invalid"):
            with self.subTest(value=value):
                result, path = self.timed(value, [sys.executable, "-c", "pass"], value)
                self.assertEqual(result.returncode, 1, result.stderr)
                self.assertIn("Invalid timeout", result.stderr)
                self.assertFalse(path.exists())

    def summarize(self) -> subprocess.CompletedProcess:
        return subprocess.run(
            [sys.executable, str(SUMMARY), str(self.root)],
            capture_output=True, text=True, timeout=5, check=False,
        )

    def write_json(self, name: str, value: object) -> None:
        (self.root / name).write_text(json.dumps(value), encoding="utf-8")

    def test_summary_includes_import_failed_processes_and_samples(self) -> None:
        self.write_json("import.timing.json", {"elapsed_ms": 18, "exit_code": 0, "timed_out": False, "timeout_seconds": 180})
        self.write_json("failed.timing.json", {"elapsed_ms": 50, "exit_code": 124, "timed_out": True, "timeout_seconds": 0.05})
        # Old timing files have no timed_out field; show unknown rather than
        # guessing whether a process that exited 124 actually timed out.
        self.write_json("naming_conventions.timing.json", {"elapsed_ms": 22, "exit_code": 2, "timeout_seconds": 180})
        self.write_json("naming_conventions.json", {
            "summary": {"entries": 3, "issues": 2},
            "issues": [
                {"kind": "file_name", "path": "res://Bad.png", "message": "bad  name"},
                {"kind": "signal_name", "path": "res://player.gd", "line": 12, "message": "bad signal"},
            ],
        })
        result = self.summarize()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("process import: elapsed_ms=18 exit_code=0 timed_out=false", result.stdout)
        self.assertIn("process failed: elapsed_ms=50 exit_code=124 timed_out=true", result.stdout)
        self.assertIn('exit_code=2 timed_out="unknown"', result.stdout)
        self.assertIn('"file_name": 1', result.stdout)
        self.assertIn("sample file_name res://Bad.png: bad name", result.stdout)
        self.assertIn("sample signal_name res://player.gd:12: bad signal", result.stdout)
        self.assertNotIn("res://Bad.png:0", result.stdout)

    def test_partial_and_invalid_reports_fail_visibly(self) -> None:
        self.write_json("import.timing.json", {"elapsed_ms": 23, "exit_code": 1})
        partial = self.summarize()
        self.assertEqual(partial.returncode, 1)
        self.assertIn("process import: elapsed_ms=23", partial.stdout)
        self.assertIn("No dogfood reports", partial.stderr)

        (self.root / "broken.json").write_text("{", encoding="utf-8")
        invalid = self.summarize()
        self.assertEqual(invalid.returncode, 1)
        self.assertIn("unreadable", invalid.stderr)

        self.write_json("broken.json", {"summary": {}, "issues": ["not an object"]})
        invalid = self.summarize()
        self.assertEqual(invalid.returncode, 1)
        self.assertIn("issues must be an array of objects", invalid.stderr)

    def test_report_without_timing_is_explicit(self) -> None:
        self.write_json("naming_conventions.json", {"summary": {"issues": 0}, "issues": []})
        result = self.summarize()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("process timings: not recorded", result.stdout)
        self.assertIn("timing=not_recorded", result.stdout)


if __name__ == "__main__":
    unittest.main(verbosity=2)
