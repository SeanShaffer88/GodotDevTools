#!/usr/bin/env python3
"""Unit-test the Docker smoke driver without requiring a Docker daemon."""
from __future__ import annotations

import contextlib
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import unittest
from unittest.mock import patch

import docker_smoke as smoke


class FakeDocker:
    def __init__(self, variant: str = "ok") -> None:
        self.variant = variant
        self.calls: list[list[str]] = []
        self.project: Path | None = None

    def __call__(self, command: list[str], **kwargs: object) -> subprocess.CompletedProcess:
        self.calls.append(command)
        assert command[:3] == ["fake-docker", "run", "--rm"]
        assert "--pull=never" in command
        assert command[command.index("--name") + 1].startswith("gdt-smoke-")
        assert command[command.index("--network") + 1] == "none"
        assert command[command.index("--user") + 1] == f"{os.getuid()}:{os.getgid()}"
        assert command[command.index("--env") + 1] == "HOME=/tmp"
        assert kwargs.get("timeout") == 120
        mount = command[command.index("--volume") + 1]
        assert mount.endswith(":/work")
        self.project = Path(mount[:-len(":/work")])
        assert (self.project / "project.godot").is_file()
        assert (self.project / "addons/suite_dispatcher/cli/gdt_cli.gd").is_file()
        assert (self.project / "addons/android_export_audit/cli/aea_cli.gd").is_file()
        args = command[command.index("fake-image") + 1:]
        if args == ["list"]:
            output = "suite_dispatcher Suite CLI Dispatcher\n"
            if self.variant != "missing_listing":
                output += "android_export_audit Android Export Readiness Audit\n"
            return subprocess.CompletedProcess(command, 0, output, "")
        if args == ["run", "not_a_real_tool"]:
            message = "other error" if self.variant == "wrong_unknown_message" else "Unknown or ambiguous tool: not_a_real_tool"
            return subprocess.CompletedProcess(command, 1, "", message)

        assert args[:2] == ["run", "android_export_audit"]
        output_arg = next(a for a in args if a.startswith("--out=res://reports/"))
        label = output_arg.rsplit("/", 1)[-1]
        assert label in ("clean", "finding", "missing")
        assert (self.project / "demo/android_dev/export_clean.cfg").is_file()
        assert (self.project / "demo/android_dev/export_presets.cfg").is_file()
        assert (self.project / "demo/android_dev/release_history.json").is_file()
        code = {"clean": 0, "finding": 2, "missing": 1}[label]
        issue = {"clean": None, "finding": "version_not_increased", "missing": "bad_input"}[label]
        if self.variant == "wrong_finding" and label == "finding":
            issue = "embedded_password"
        if self.variant == "wrong_input_issue" and label == "missing":
            issue = "other"
        if self.variant == "dirty_clean" and label == "clean":
            issue = "example_package"
        issues = [] if issue is None else [{"kind": issue}]
        data = {"summary": {"android_presets": 1 if label == "clean" else 0, "issues": len(issues)},
                "issues": issues}
        if self.variant == "wrong_issue_count" and label == "finding":
            data["summary"]["issues"] = 0
        report_dir = self.project / "reports" / label
        report_dir.mkdir(parents=True)
        if self.variant == "secret_in_report" and label == "finding":
            data["leaked"] = smoke.SECRET_MARKER
        raw = json.dumps(data)
        if self.variant == "malformed_json" and label == "clean":
            raw = "not json"
        (report_dir / "android_export_audit.json").write_text(raw, encoding="utf-8")
        if not (self.variant == "missing_markdown" and label == "clean"):
            (report_dir / "android_export_audit.md").write_text("# Synthetic report\n", encoding="utf-8")
        if self.variant == "wrong_exit" and label == "finding":
            code = 0
        output = "SCRIPT ERROR: synthetic failure\n" if self.variant == "script_error" and label == "clean" else ""
        return subprocess.CompletedProcess(command, code, output, "")


@unittest.skipUnless(hasattr(os, "getuid"), "Linux/Unix host required")
class DockerSmokeDriverTests(unittest.TestCase):
    def run_driver(self, fake: FakeDocker) -> None:
        with patch.object(smoke.subprocess, "run", side_effect=fake), contextlib.redirect_stdout(io.StringIO()):
            smoke.run_smoke("fake-docker", "fake-image")

    def test_success_and_disposable_project(self) -> None:
        fake = FakeDocker()
        self.run_driver(fake)
        self.assertEqual(len(fake.calls), 5)
        self.assertIsNotNone(fake.project)
        self.assertFalse(fake.project.exists())

    def test_finding_must_exit_two(self) -> None:
        fake = FakeDocker("wrong_exit")
        with self.assertRaisesRegex(smoke.SmokeFailure, "expected exit 2, got 0"):
            self.run_driver(fake)
        self.assertIsNotNone(fake.project)
        self.assertFalse(fake.project.exists())

    def test_fixture_must_contain_the_fake_secret(self) -> None:
        fake = FakeDocker()
        with patch.object(smoke, "SECRET_MARKER", "ABSENT_FAKE_SECRET"), \
             self.assertRaisesRegex(smoke.SmokeFailure, "fixture must contain the fake secret"):
            self.run_driver(fake)
        self.assertEqual(fake.calls, [])

    def test_listing_and_dispatch_error_are_verified(self) -> None:
        for variant in ("missing_listing", "wrong_unknown_message"):
            with self.subTest(variant=variant), self.assertRaises(smoke.SmokeFailure):
                self.run_driver(FakeDocker(variant))

    def test_report_contents_are_checked(self) -> None:
        expected = {
            "missing_markdown": "cannot read the JSON/Markdown reports",
            "malformed_json": "cannot read the JSON/Markdown reports",
            "secret_in_report": "fixture secret appeared in a report",
            "wrong_issue_count": "report issue count does not match",
            "wrong_finding": "version_not_increased missing",
            "wrong_input_issue": "bad_input missing",
            "dirty_clean": "expected one Android preset and no issues",
        }
        for variant, message in expected.items():
            with self.subTest(variant=variant), self.assertRaisesRegex(smoke.SmokeFailure, message):
                self.run_driver(FakeDocker(variant))

    def test_script_error_fails_even_on_zero_exit(self) -> None:
        with self.assertRaisesRegex(smoke.SmokeFailure, "Godot script error"):
            self.run_driver(FakeDocker("script_error"))

    def test_docker_launch_errors_fail(self) -> None:
        with patch.object(smoke.subprocess, "run", side_effect=OSError("no Docker")), \
             contextlib.redirect_stdout(io.StringIO()), self.assertRaisesRegex(smoke.SmokeFailure, "could not run Docker"):
            smoke.run_smoke("fake-docker", "fake-image")

    def test_cli_reports_failure(self) -> None:
        with patch.object(sys, "argv", ["docker_smoke.py", "--docker", "fake-docker", "--image", "fake-image"]), \
             patch.object(smoke, "run_smoke", side_effect=smoke.SmokeFailure("synthetic")) as run, \
             contextlib.redirect_stderr(io.StringIO()) as error:
            self.assertEqual(smoke.main(), 1)
        run.assert_called_once_with("fake-docker", "fake-image")
        self.assertIn("FAIL: synthetic", error.getvalue())

    def test_timeout_attempts_to_remove_the_container(self) -> None:
        calls: list[list[str]] = []

        def timed_out(command: list[str], **kwargs: object) -> subprocess.CompletedProcess:
            calls.append(command)
            if command[1] == "run":
                raise subprocess.TimeoutExpired(command, 120)
            return subprocess.CompletedProcess(command, 0, b"", b"")

        with patch.object(smoke.subprocess, "run", side_effect=timed_out), \
             contextlib.redirect_stdout(io.StringIO()), self.assertRaisesRegex(smoke.SmokeFailure, "could not run Docker"):
            smoke.run_smoke("fake-docker", "fake-image")
        self.assertEqual(len(calls), 2)
        name = calls[0][calls[0].index("--name") + 1]
        self.assertEqual(calls[1], ["fake-docker", "rm", "--force", name])


if __name__ == "__main__":
    unittest.main(verbosity=2)
