#!/usr/bin/env python3
"""Test the mounted Docker gate runner without a Docker daemon."""
from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
RUNNER = ROOT / "tests/docker_gate.sh"
FAKE_DOCKER = r'''#!/usr/bin/env python3
import json, os, pathlib, sys, time
args = sys.argv[1:]
with open(os.environ["FAKE_TRACE"], "a", encoding="utf-8") as trace:
    trace.write(json.dumps(args) + "\n")
if args[0] == "rm":
    assert args[1] == "--force"
    sys.exit(1 if os.environ.get("FAKE_MODE") == "failure_cleanup" else 0)
assert args[0] == "run"
assert "--rm" in args and "--pull=never" in args and "--network=none" in args
assert args[args.index("--user") + 1] == f"{os.getuid()}:{os.getgid()}"
assert args[args.index("--env") + 1] == "HOME=/tmp"
volume = args[args.index("--volume") + 1]
assert volume.endswith(":/work")
project = pathlib.Path(volume[:-len(":/work")])
assert (project / "project.godot").is_file()
assert (project / "tests/run_tests.sh").is_file()
assert (project / "addons/android_export_audit/plugin.cfg").is_file()
assert not (project / ".git").exists()
assert not (project / ".godot").exists()
assert not (project / "reports").exists()
assert not (project / "visual_reports").exists()
assert args[-2:] == ["fake-image", "gate"]
mode = os.environ.get("FAKE_MODE", "ok")
if mode == "host_wrapper":
    # Exercise the actual gdt gate wrapper, but substitute a tiny gate script.
    stub = project / "tests/run_tests.sh"
    stub.write_text("""#!/bin/sh
set -e
[ "$1" = "/fake/godot" ]
mkdir -p reports/android_export_audit visual_reports
printf '{}\\n' > reports/android_export_audit/android_export_audit.json
printf 'image' > visual_reports/menu__320x240.highlight.png
echo 'STUB GATE received /fake/godot'
echo 'ALL GATE CHECKS PASSED'
""", encoding="utf-8")
    os.chdir(project)
    os.environ["GODOT_BIN"] = "/fake/godot"
    os.execv(str(project / "tools/gdt"), ["gdt", "gate"])
if mode in ("failure", "failure_cleanup"):
    print("synthetic 50% failure", flush=True)
    print("second line", flush=True)
    sys.exit(17)
if mode == "long_failure":
    print("x" * 30000 + " end 50%", flush=True)
    sys.exit(17)
if mode == "timeout":
    print("synthetic long gate", flush=True)
    time.sleep(10)
if mode != "missing_reports":
    report = project / "reports/android_export_audit/android_export_audit.json"
    report.parent.mkdir(parents=True)
    report.write_text("{}", encoding="utf-8")
    image = project / "visual_reports/menu__320x240.highlight.png"
    image.parent.mkdir(parents=True)
    image.write_bytes(b"fake image")
if mode != "missing_marker":
    print("ALL GATE CHECKS PASSED", flush=True)
'''


class DockerGateTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory(prefix="gdt-gate-test-")
        self.work = Path(self.temp.name)
        self.docker = self.work / "fake-docker"
        self.docker.write_text(FAKE_DOCKER, encoding="utf-8")
        self.docker.chmod(0o755)
        self.trace = self.work / "docker-trace.jsonl"
        self.summary = self.work / "summary.md"

    def tearDown(self) -> None:
        self.temp.cleanup()

    def run_gate(self, mode: str = "ok", extra_env: dict[str, str] | None = None) -> subprocess.CompletedProcess:
        env = os.environ.copy()
        # Expected fake failures must not write to the real Actions step summary.
        for key in ("GITHUB_ACTIONS", "GITHUB_STEP_SUMMARY", "GDT_DOCKER_GATE_TIMEOUT"):
            env.pop(key, None)
        env.update({
            "TMPDIR": str(self.work), "GDT_DOCKER": str(self.docker),
            "FAKE_TRACE": str(self.trace), "FAKE_MODE": mode,
        })
        if extra_env:
            env.update(extra_env)
        result = subprocess.run(["bash", str(RUNNER), "fake-image"], cwd=ROOT, env=env,
                                text=True, capture_output=True, timeout=30, check=False)
        self.assertEqual(list(self.work.rglob("gdt-docker-gate.*")), [], "temporary project was not removed")
        return result

    def calls(self) -> list[list[str]]:
        if not self.trace.exists():
            return []
        return [json.loads(line) for line in self.trace.read_text(encoding="utf-8").splitlines()]

    def assert_container_cleanup(self) -> None:
        calls = self.calls()
        self.assertEqual(len(calls), 2)
        self.assertEqual(calls[0][0], "run")
        name = calls[0][calls[0].index("--name") + 1]
        self.assertEqual(calls[1], ["rm", "--force", name])

    def test_gate_and_disposable_mount(self) -> None:
        result = self.run_gate()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("Mounted Docker gate passed.", result.stdout)
        self.assert_container_cleanup()

    def test_real_gdt_gate_wrapper_with_stub_gate(self) -> None:
        result = self.run_gate("host_wrapper")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("STUB GATE received /fake/godot", result.stdout)
        self.assert_container_cleanup()

    def test_temporary_path_with_spaces(self) -> None:
        parent = self.work / "temporary path with spaces"
        parent.mkdir()
        result = self.run_gate(extra_env={"TMPDIR": str(parent)})
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assert_container_cleanup()

    def test_failure_status_and_diagnostics_are_preserved(self) -> None:
        result = self.run_gate("failure", {"GITHUB_ACTIONS": "true", "GITHUB_STEP_SUMMARY": str(self.summary)})
        self.assertEqual(result.returncode, 17, result.stdout + result.stderr)
        self.assertIn("::error title=Mounted Docker gate failed (exit 17)::", result.stdout)
        self.assertIn("synthetic 50%25 failure%0Asecond line", result.stdout)
        self.assertIn("synthetic 50% failure", self.summary.read_text(encoding="utf-8"))
        self.assert_container_cleanup()

    def test_failure_summary_is_bounded(self) -> None:
        result = self.run_gate("long_failure", {"GITHUB_ACTIONS": "true", "GITHUB_STEP_SUMMARY": str(self.summary)})
        self.assertEqual(result.returncode, 17, result.stdout + result.stderr)
        self.assertLess(len(self.summary.read_bytes()), 20100)
        annotation = next(line for line in result.stdout.splitlines() if line.startswith("::error title="))
        self.assertLess(len(annotation), 36100)
        self.assert_container_cleanup()

    def test_failed_container_cleanup_warns_without_masking_failure(self) -> None:
        result = self.run_gate("failure_cleanup")
        self.assertEqual(result.returncode, 17, result.stdout + result.stderr)
        self.assertIn("check whether container", result.stderr)
        self.assert_container_cleanup()

    def test_summary_write_failure_does_not_mask_gate_exit(self) -> None:
        result = self.run_gate("failure", {"GITHUB_ACTIONS": "true", "GITHUB_STEP_SUMMARY": str(self.work)})
        self.assertEqual(result.returncode, 17, result.stdout + result.stderr)
        self.assertIn("could not write the GitHub step summary", result.stderr)
        self.assert_container_cleanup()

    def test_success_requires_marker_and_reports(self) -> None:
        for mode, message in (("missing_marker", "success marker is missing"),
                              ("missing_reports", "expected gate reports were not written")):
            with self.subTest(mode=mode):
                self.trace.unlink(missing_ok=True)
                result = self.run_gate(mode)
                self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                self.assertIn(message, result.stderr)
                self.assert_container_cleanup()

    def test_timeout_removes_container(self) -> None:
        result = self.run_gate("timeout", {"GDT_DOCKER_GATE_TIMEOUT": "0.2s"})
        self.assertEqual(result.returncode, 124, result.stdout + result.stderr)
        self.assert_container_cleanup()

    def test_archive_failure_does_not_start_container(self) -> None:
        bindir = self.work / "bin"
        bindir.mkdir()
        bad_git = bindir / "git"
        bad_git.write_text("#!/bin/sh\necho synthetic archive failure >&2\nexit 23\n", encoding="utf-8")
        bad_git.chmod(0o755)
        result = self.run_gate(extra_env={"PATH": f"{bindir}:{os.environ['PATH']}"})
        self.assertEqual(result.returncode, 23, result.stdout + result.stderr)
        self.assertIn("synthetic archive failure", result.stderr)
        self.assertEqual(self.calls(), [])

    def test_log_write_failure_fails_the_gate(self) -> None:
        bindir = self.work / "bin"
        bindir.mkdir()
        bad_tee = bindir / "tee"
        bad_tee.write_text("#!/bin/sh\ncat >/dev/null\nexit 5\n", encoding="utf-8")
        bad_tee.chmod(0o755)
        result = self.run_gate(extra_env={"PATH": f"{bindir}:{os.environ['PATH']}"})
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("could not save the Docker gate log", result.stderr)
        self.assert_container_cleanup()
        self.trace.unlink()
        result = self.run_gate("failure", {"PATH": f"{bindir}:{os.environ['PATH']}", "GITHUB_ACTIONS": "true",
                                           "GITHUB_STEP_SUMMARY": str(self.summary)})
        self.assertEqual(result.returncode, 17, result.stdout + result.stderr)
        self.assertIn("(gate log unavailable)", result.stdout)
        self.assert_container_cleanup()


if __name__ == "__main__":
    unittest.main(verbosity=2)
