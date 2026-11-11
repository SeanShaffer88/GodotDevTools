#!/usr/bin/env python3
"""Exercise the built image against a disposable, mounted Godot project.

Linux Docker host and Python 3 required. The image must already be built:
    docker build -t godot-dev-tools .
    python3 tests/docker_smoke.py --image godot-dev-tools
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import uuid


ROOT = Path(__file__).resolve().parents[1]
SECRET_MARKER = "DEMO_SECRET_NOT_REAL"


class SmokeFailure(Exception):
    """A smoke-test assertion failed."""


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SmokeFailure(message)


def make_project(project: Path) -> None:
    """Copy only the dispatcher, tested addon and synthetic inputs."""
    (project / "addons").mkdir(parents=True)
    for addon in ("suite_dispatcher", "android_export_audit"):
        shutil.copytree(ROOT / "addons" / addon, project / "addons" / addon)
    (project / "demo" / "android_dev").mkdir(parents=True)
    for name in ("export_clean.cfg", "export_presets.cfg", "release_history.json"):
        shutil.copy2(ROOT / "demo" / "android_dev" / name, project / "demo" / "android_dev" / name)
    require(SECRET_MARKER in (project / "demo/android_dev/export_presets.cfg").read_text(encoding="utf-8"),
            "the problem fixture must contain the fake secret marker")
    (project / "project.godot").write_text(
        'config_version=5\n[application]\nconfig/name="Docker smoke"\n', encoding="utf-8"
    )


def run_container(docker: str, image: str, project: Path, label: str, expected: int, args: list[str]) -> str:
    name = f"gdt-smoke-{uuid.uuid4().hex}"
    command = [
        docker, "run", "--rm", "--pull=never", "--name", name, "--network", "none", "--user", f"{os.getuid()}:{os.getgid()}",
        "--env", "HOME=/tmp", "--volume", f"{project}:/work", image, *args,
    ]
    try:
        result = subprocess.run(command, capture_output=True, text=True, errors="replace", timeout=120, check=False)
    except subprocess.TimeoutExpired as exc:
        # Killing the CLI on timeout does not necessarily stop its container.
        cleanup_note = ""
        try:
            cleanup = subprocess.run([docker, "rm", "--force", name], capture_output=True, timeout=15, check=False)
            if cleanup.returncode != 0:
                cleanup_note = f"; check whether container {name} needs removal"
        except (OSError, subprocess.TimeoutExpired):
            cleanup_note = f"; check whether container {name} needs removal"
        raise SmokeFailure(f"{label}: could not run Docker: {exc}{cleanup_note}") from exc
    except OSError as exc:
        raise SmokeFailure(f"{label}: could not run Docker: {exc}") from exc
    output = result.stdout + result.stderr
    print(f"== {label}: exit {result.returncode} (expected {expected}) ==")
    print(output, end="" if output.endswith("\n") else "\n")
    require(result.returncode == expected, f"{label}: expected exit {expected}, got {result.returncode}")
    require("SCRIPT ERROR:" not in output and "Parse Error:" not in output, f"{label}: Godot script error")
    require(SECRET_MARKER not in output, f"{label}: fixture secret appeared in output")
    return output


def read_report(project: Path, label: str) -> dict:
    base = project / "reports" / label
    json_path = base / "android_export_audit.json"
    markdown_path = base / "android_export_audit.md"
    try:
        raw = json_path.read_text(encoding="utf-8")
        markdown = markdown_path.read_text(encoding="utf-8")
        data = json.loads(raw)
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise SmokeFailure(f"{label}: cannot read the JSON/Markdown reports: {exc}") from exc
    require(bool(markdown.strip()), f"{label}: Markdown report is empty")
    require(SECRET_MARKER not in raw and SECRET_MARKER not in markdown, f"{label}: fixture secret appeared in a report")
    require(isinstance(data, dict) and isinstance(data.get("summary"), dict) and isinstance(data.get("issues"), list),
            f"{label}: unexpected report structure")
    require(data["summary"].get("issues") == len(data["issues"]), f"{label}: report issue count does not match")
    return data


def run_smoke(docker: str, image: str) -> None:
    if not hasattr(os, "getuid"):
        raise SmokeFailure("The mounted-project smoke test requires a Linux/Unix Docker host.")
    # A disposable mount prevents test reports or Godot data from touching the checkout.
    with tempfile.TemporaryDirectory(prefix="gdt-docker-smoke-") as tmp:
        project = Path(tmp) / "project"
        make_project(project)
        listing = run_container(docker, image, project, "list mounted tools", 0, ["list"])
        require(re.search(r"(?m)^android_export_audit\s", listing) is not None,
                "list: mounted Android export addon was not discovered")

        run_container(docker, image, project, "clean audit", 0, [
            "run", "android_export_audit", "--presets=res://demo/android_dev/export_clean.cfg",
            "--out=res://reports/clean", "--fail-on=issues",
        ])
        clean = read_report(project, "clean")
        require(clean["summary"].get("android_presets") == 1 and not clean["issues"],
                "clean audit: expected one Android preset and no issues")

        run_container(docker, image, project, "selected finding", 2, [
            "run", "android_export_audit", "--presets=res://demo/android_dev/export_presets.cfg",
            "--history=res://demo/android_dev/release_history.json", "--out=res://reports/finding",
            "--fail-on=version_not_increased",
        ])
        finding = read_report(project, "finding")
        require(any(isinstance(i, dict) and i.get("kind") == "version_not_increased" for i in finding["issues"]),
                "selected finding: version_not_increased missing from report")

        run_container(docker, image, project, "missing input", 1, [
            "run", "android_export_audit", "--presets=res://demo/android_dev/missing.cfg",
            "--out=res://reports/missing",
        ])
        missing = read_report(project, "missing")
        require(any(isinstance(i, dict) and i.get("kind") == "bad_input" for i in missing["issues"]),
                "missing input: bad_input missing from report")

        unknown = run_container(docker, image, project, "unknown tool", 1, ["run", "not_a_real_tool"])
        require("Unknown or ambiguous tool:" in unknown, "unknown tool: dispatcher error message missing")
    print("Mounted-project smoke assertions passed.")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--image", default="godot-dev-tools", help="Previously built Docker image")
    parser.add_argument("--docker", default="docker", help="Docker executable")
    args = parser.parse_args()
    try:
        run_smoke(args.docker, args.image)
    except SmokeFailure as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
