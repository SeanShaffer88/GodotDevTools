#!/usr/bin/env python3
"""Run one archived addon from both release archive types in disposable projects."""

import argparse
import json
from pathlib import Path, PurePosixPath
import shutil
import subprocess
import sys
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools" / "release"))
import build_archives
from release_manifest import archive_name

SECRET = "DEMO_SECRET_NOT_REAL"


class SmokeFailure(Exception):
    pass


def require(condition, message):
    if not condition:
        raise SmokeFailure(message)


def extract_checked(archive_path, project):
    with zipfile.ZipFile(archive_path) as archive:
        names = archive.namelist()
        require(len(names) == len(set(names)), f"duplicate archive paths in {archive_path.name}")
        for name in names:
            path = PurePosixPath(name)
            require(not path.is_absolute() and ".." not in path.parts and "\\" not in name
                    and path.parts and path.parts[0] == "addons", f"unsafe archive path: {name}")
        archive.extractall(project)


def run_cli(godot, project, label, expected_exit, args):
    command = [str(godot), "--headless", "--path", str(project), "--script",
               "res://addons/android_export_audit/cli/aea_cli.gd", "--", *args]
    try:
        result = subprocess.run(command, cwd=project, capture_output=True, text=True,
                                errors="replace", timeout=60, check=False)
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise SmokeFailure(f"{label}: could not run Godot: {exc}") from exc
    output = result.stdout + result.stderr
    require(result.returncode == expected_exit,
            f"{label}: expected exit {expected_exit}, got {result.returncode}\n{output}")
    require("SCRIPT ERROR" not in output and "Parse Error" not in output,
            f"{label}: Godot reported a script error\n{output}")
    require(SECRET not in output, f"{label}: fixture secret appeared in output")
    return output


def read_report(project, label):
    directory = project / "reports" / label
    try:
        raw = (directory / "android_export_audit.json").read_text(encoding="utf-8")
        markdown = (directory / "android_export_audit.md").read_text(encoding="utf-8")
        report = json.loads(raw)
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise SmokeFailure(f"{label}: could not read reports: {exc}") from exc
    require(SECRET not in raw and SECRET not in markdown, f"{label}: fixture secret appeared in reports")
    require(bool(markdown.strip()) and isinstance(report, dict)
            and isinstance(report.get("summary"), dict) and isinstance(report.get("issues"), list),
            f"{label}: invalid report structure")
    require(report["summary"].get("issues") == len(report["issues"]), f"{label}: wrong issue count")
    return report


def run_smoke(godot):
    # This tag is only a local filename; no tag or GitHub Release is created.
    tag = "v0.0.0"
    with tempfile.TemporaryDirectory(prefix="gdt-release-install-") as tmp:
        work = Path(tmp)
        archives = work / "archives"
        build_archives.build(ROOT, archives, tag)
        for kind, stem in (("addon", "AndroidExportAudit"), ("suite", "Suite")):
            project = work / kind
            project.mkdir()
            extract_checked(archives / archive_name(stem, tag), project)
            if kind == "addon":
                require({p.name for p in (project / "addons").iterdir()} == {"android_export_audit"},
                        "single-addon archive contained unexpected addons")
            require((project / "addons/android_export_audit/LICENSE").read_bytes() == (ROOT / "LICENSE").read_bytes(),
                    f"{kind}: packaged MIT notice is missing")
            (project / "project.godot").write_text(
                'config_version=5\n[application]\nconfig/name="Archive smoke"\n', encoding="utf-8"
            )
            fixtures = project / "demo/android_dev"
            fixtures.mkdir(parents=True)
            for filename in ("export_clean.cfg", "export_presets.cfg", "release_history.json"):
                shutil.copyfile(ROOT / "demo/android_dev" / filename, fixtures / filename)
            require(SECRET in (fixtures / "export_presets.cfg").read_text(encoding="utf-8"),
                    "problem fixture is missing its fake secret")

            run_cli(godot, project, f"{kind} clean", 0, [
                "--presets=res://demo/android_dev/export_clean.cfg", "--out=res://reports/clean", "--fail-on=issues",
            ])
            clean = read_report(project, "clean")
            require(clean["summary"].get("android_presets") == 1 and not clean["issues"], f"{kind}: clean audit failed")
            run_cli(godot, project, f"{kind} finding", 2, [
                "--presets=res://demo/android_dev/export_presets.cfg", "--history=res://demo/android_dev/release_history.json",
                "--out=res://reports/finding", "--fail-on=version_not_increased",
            ])
            finding = read_report(project, "finding")
            require(any(isinstance(issue, dict) and issue.get("kind") == "version_not_increased"
                        for issue in finding["issues"]), f"{kind}: expected finding missing")
            run_cli(godot, project, f"{kind} invalid input", 1, [
                "--presets=res://demo/android_dev/missing.cfg", "--out=res://reports/missing",
            ])
            missing = read_report(project, "missing")
            require(any(isinstance(issue, dict) and issue.get("kind") == "bad_input"
                        for issue in missing["issues"]), f"{kind}: expected input error missing")
            print(f"{kind}: installed Android export audit passed 0/2/1 exit and report checks")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True, help="Godot 4.3 executable")
    args = parser.parse_args(argv)
    try:
        run_smoke(args.godot)
    except (SmokeFailure, build_archives.ManifestError, OSError, zipfile.BadZipFile) as exc:
        print(f"release install smoke: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
