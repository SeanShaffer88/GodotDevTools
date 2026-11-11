#!/usr/bin/env python3
"""Standalone naming regressions and, when GDT_GODOT_BIN is set, CLI parity."""
from __future__ import annotations

import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[1]
STANDALONE = REPO / "tools/standalone/standalone.py"
GODOT = os.environ.get("GDT_GODOT_BIN")
EXPECTED = {
    ("file_name", "BadAsset.png"),
    ("file_name", "BadCode.gd"),
    ("file_name", "BadSingle.import"),
    ("file_name", "BadSingle.uid"),
    ("file_name", "non_sidecar.bad.ext"),
    ("file_name", "Bad.script.uid/BadChild.gd"),
    ("directory_name", "Bad.folder.import"),
    ("directory_name", "Bad.script.uid"),
}


def make_fixture(root: Path) -> None:
    for directory in ("Bad.folder.import", "Bad.script.uid", "addons", "reports", "visual_reports", ".hidden"):
        (root / directory).mkdir(parents=True, exist_ok=True)
    for name in (
        "good.png", "good.png.import", "BadAsset.png", "BadAsset.png.import",
        "BadCode.gd", "BadCode.gd.uid", "orphan.svg.import", "orphan.gd.uid",
        "other.png.IMPORT", "BadSingle.import", "BadSingle.uid", "non_sidecar.bad.ext",
        "Bad.folder.import/good_child.txt", "Bad.script.uid/BadChild.gd",
        "addons/BadExcluded.gd", "reports/BadExcluded.gd",
        "visual_reports/BadExcluded.gd", ".hidden/BadExcluded.gd",
    ):
        (root / name).write_text("fixture", encoding="utf-8")


def standalone(root: Path, pattern: str | None = None, cwd: Path | None = None) -> subprocess.CompletedProcess:
    args = [sys.executable, str(STANDALONE), "naming", f"--dir={root}"]
    if pattern is not None:
        args.append(f"--pattern={pattern}")
    return subprocess.run(args, cwd=cwd, capture_output=True, text=True, timeout=20, check=False)


def python_findings(output: str, root: Path) -> set[tuple[str, str]]:
    findings = set()
    for line in output.splitlines():
        match = re.fullmatch(r"\[([a-z_]+)\] (.*): Name '.*' does not match .*", line)
        if match is None:
            raise AssertionError(f"unexpected standalone output: {line}")
        path = Path(match.group(2))
        if not path.is_absolute():
            path = root / path
        findings.add((match.group(1), path.relative_to(root).as_posix()))
    return findings


class StandaloneTests(unittest.TestCase):
    def setUp(self) -> None:
        # Excluded/hidden ancestors of the selected scan root must not suppress
        # its contents. Only entries *within* that root are excluded.
        self.temp = tempfile.TemporaryDirectory(prefix=".gdt-standalone-")
        self.project = Path(self.temp.name) / "addons" / "project"
        self.fixture = self.project / "fixtures"
        make_fixture(self.fixture)

    def tearDown(self) -> None:
        self.temp.cleanup()

    def test_file_and_directory_findings_and_sidecars(self) -> None:
        result = standalone(self.fixture)
        self.assertEqual(result.returncode, 2, result.stderr)
        self.assertEqual(python_findings(result.stdout, self.fixture), EXPECTED)

        relative = standalone(Path("."), cwd=self.fixture)
        self.assertEqual(relative.returncode, 2, relative.stderr)
        self.assertEqual(python_findings(relative.stdout, self.fixture), EXPECTED)

    def test_demo_fixture(self) -> None:
        fixture = REPO / "demo/naming"
        result = standalone(fixture)
        self.assertEqual(result.returncode, 2, result.stderr)
        self.assertEqual(python_findings(result.stdout, fixture), {
            ("directory_name", "BadFolder"),
            ("file_name", "BadFolder/BadName.txt"),
        })

    def test_custom_pattern_and_errors(self) -> None:
        clean = standalone(self.fixture, r"^[A-Za-z][A-Za-z0-9_.-]*$")
        self.assertEqual(clean.returncode, 0, clean.stderr)
        self.assertEqual(clean.stdout, "")
        for pattern in ("", "["):
            result = standalone(self.fixture, pattern)
            self.assertEqual(result.returncode, 1)
            self.assertIn("Invalid naming pattern", result.stderr)
        missing = standalone(self.project / "missing")
        self.assertEqual(missing.returncode, 1)
        self.assertIn("Cannot open scan directory", missing.stderr)

    @unittest.skipUnless(GODOT, "set GDT_GODOT_BIN to compare against Godot CLI")
    def test_godot_cli_parity(self) -> None:
        (self.project / "project.godot").write_text(
            'config_version=5\n[application]\nconfig/name="Naming parity fixture"\n',
            encoding="utf-8",
        )
        addon = self.project / "addons/naming_conventions"
        for directory in ("core", "cli"):
            shutil.copytree(REPO / "addons/naming_conventions" / directory, addon / directory)

        def godot_scan(pattern: str | None = None) -> tuple[subprocess.CompletedProcess, dict]:
            args = [
                GODOT, "--headless", "--path", str(self.project), "--script",
                "res://addons/naming_conventions/cli/nc_cli.gd", "--",
                "--dir=res://fixtures", "--out=res://reports/naming", "--fail-on=issues",
            ]
            if pattern is not None:
                args.append(f"--pattern={pattern}")
            result = subprocess.run(args, capture_output=True, text=True, timeout=60, check=False)
            report = self.project / "reports/naming/naming_conventions.json"
            self.assertTrue(report.is_file(), result.stdout + result.stderr)
            return result, json.loads(report.read_text(encoding="utf-8"))

        result, data = godot_scan()
        self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
        self.assertEqual(data["summary"], {"entries": 10, "issues": len(EXPECTED)})
        prefix = "res://fixtures/"
        self.assertTrue(all(issue["path"].startswith(prefix) for issue in data["issues"]))
        findings = {(issue["kind"], issue["path"][len(prefix):]) for issue in data["issues"]}
        python_result = standalone(self.fixture)
        self.assertEqual(findings, EXPECTED)
        self.assertEqual(findings, python_findings(python_result.stdout, self.fixture))
        self.assertEqual(result.returncode, python_result.returncode)

        pattern = r"^[A-Za-z][A-Za-z0-9_.-]*$"
        result, data = godot_scan(pattern)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(data["summary"], {"entries": 10, "issues": 0})
        self.assertEqual(standalone(self.fixture, pattern).returncode, 0)


if __name__ == "__main__":
    unittest.main(verbosity=2)
