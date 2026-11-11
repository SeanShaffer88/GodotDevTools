#!/usr/bin/env python3
"""Offline release packaging and Asset Library regression tests."""

import contextlib
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock
import zipfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools" / "release"))
sys.path.insert(0, str(ROOT / "tools" / "assetlib"))
import build_archives
import generate_assetlib
import release_install_smoke
import release_manifest


FAKE_GODOT = r'''#!/usr/bin/env python3
import json, os, pathlib, sys
args = sys.argv[1:]
project = pathlib.Path(args[args.index("--path") + 1])
assert args[args.index("--script") + 1] == "res://addons/android_export_audit/cli/aea_cli.gd"
assert (project / "addons/android_export_audit/LICENSE").is_file()
assert (project / "addons/android_export_audit/core/aea_audit.gd").is_file()
with open(os.environ["GDT_FAKE_TRACE"], "a", encoding="utf-8") as trace:
    trace.write(json.dumps(args) + "\n")
preset = next(x.split("=", 1)[1] for x in args if x.startswith("--presets="))
out = next(x.split("=", 1)[1] for x in args if x.startswith("--out="))
assert out.startswith("res://")
directory = project / out[len("res://"):]
directory.mkdir(parents=True)
if preset.endswith("export_clean.cfg"):
    issues, status = [], 0
elif preset.endswith("export_presets.cfg"):
    assert any(x.startswith("--history=") for x in args)
    issues, status = [{"kind": "version_not_increased"}], 2
else:
    issues, status = [{"kind": "bad_input"}], 1
report = {"summary": {"issues": len(issues), "android_presets": 1}, "issues": issues}
(directory / "android_export_audit.json").write_text(json.dumps(report))
(directory / "android_export_audit.md").write_text("report")
if os.environ.get("GDT_FAKE_SCRIPT_ERROR"):
    print("SCRIPT ERROR: simulated", file=sys.stderr)
sys.exit(status)
'''


class ReleaseFixtureTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="gdt-release-test-")
        self.work = Path(self.temp.name)
        self.root = self.work / "checkout"
        (self.root / "tools/release").mkdir(parents=True)
        (self.root / "LICENSE").write_text("test license\n", encoding="utf-8")
        self.mapping = {"alpha": "Alpha", "beta": "BetaSpecial"}
        self.write_manifest(self.mapping)
        for folder in self.mapping:
            addon = self.root / "addons" / folder
            (addon / "core").mkdir(parents=True)
            (addon / "plugin.cfg").write_text(
                f'[plugin]\nname="{folder}"\nversion="1.0.0"\nauthor="Test"\ndescription="Demo"\n',
                encoding="utf-8",
            )
            (addon / "core" / "script.gd").write_text(f"# {folder}\n", encoding="utf-8")
        (self.root / "addons/alpha/.hidden").write_text("included\n", encoding="utf-8")

    def tearDown(self):
        self.temp.cleanup()

    def write_manifest(self, mapping):
        (self.root / release_manifest.MANIFEST).write_text(json.dumps(mapping), encoding="utf-8")

    def test_tag_validation_and_asset_names(self):
        self.assertEqual(release_manifest.archive_name("BetaSpecial", "v2.3.4"), "GodotDevTools-BetaSpecial-v2.3.4.zip")
        for tag in ("2.3.4", "v2.3", "v2.3.4-rc1", "v2.3.4\n", "v2.3.4/../oops", "$(bad)"):
            with self.subTest(tag=tag), self.assertRaises(release_manifest.ManifestError):
                release_manifest.validate_tag(tag)

    def test_duplicate_json_keys_are_rejected(self):
        (self.root / release_manifest.MANIFEST).write_text('{"alpha": "Alpha", "alpha": "Other"}')
        with self.assertRaisesRegex(release_manifest.ManifestError, "duplicate manifest entry"):
            release_manifest.load_manifest(self.root)

    def test_invalid_and_colliding_manifest_names_are_rejected(self):
        cases = [
            ({"../alpha": "Alpha", "beta": "Beta"}, "invalid addon folder"),
            ({"alpha": "../Alpha", "beta": "Beta"}, "invalid release asset name"),
            ({"alpha": "Same", "beta": "same"}, "duplicate release asset name"),
            ({"alpha": "Suite", "beta": "Beta"}, "reserved"),
            ({"alpha": [], "beta": "Beta"}, "invalid release asset name"),
        ]
        for manifest, message in cases:
            with self.subTest(manifest=manifest):
                self.write_manifest(manifest)
                with self.assertRaisesRegex(release_manifest.ManifestError, message):
                    release_manifest.load_manifest(self.root)

    def test_missing_unlisted_and_incomplete_addons_are_rejected(self):
        self.write_manifest({"alpha": "Alpha"})
        with self.assertRaisesRegex(release_manifest.ManifestError, "unlisted folders=.*beta"):
            release_manifest.load_manifest(self.root)
        self.write_manifest({**self.mapping, "missing": "Missing"})
        with self.assertRaisesRegex(release_manifest.ManifestError, "missing folders=.*missing"):
            release_manifest.load_manifest(self.root)
        self.write_manifest(self.mapping)
        (self.root / "addons/beta/plugin.cfg").unlink()
        with self.assertRaisesRegex(release_manifest.ManifestError, "plugin.cfg"):
            release_manifest.load_manifest(self.root)

    def test_build_and_tagged_metadata_use_the_same_names_and_include_license(self):
        out = self.work / "archives with spaces"
        self.assertEqual(build_archives.build(self.root, out, "v9.8.7"), 2)
        outputs = generate_assetlib.render(self.root, "v9.8.7")
        suite_contents = {}
        for folder in self.mapping:
            metadata = json.loads(outputs[f"{folder}.json"])
            self.assertEqual(metadata["version"], "1.0.0")  # plugin version, not release tag
            zip_path = out / metadata["zip"]
            self.assertTrue(zip_path.is_file(), zip_path)
            with zipfile.ZipFile(zip_path) as archive:
                names = archive.namelist()
                self.assertEqual(len(names), len(set(names)))
                self.assertTrue(all(name.startswith(f"addons/{folder}/") for name in names))
                self.assertEqual(archive.read(f"addons/{folder}/LICENSE"), b"test license\n")
                self.assertEqual(archive.read(f"addons/{folder}/plugin.cfg"),
                                 (self.root / "addons" / folder / "plugin.cfg").read_bytes())
                suite_contents.update({name: archive.read(name) for name in names})
        with zipfile.ZipFile(out / "GodotDevTools-Suite-v9.8.7.zip") as archive:
            self.assertEqual(set(archive.namelist()), set(suite_contents))
            for name, content in suite_contents.items():
                self.assertEqual(archive.read(name), content, name)
        self.assertIn("addons/alpha/.hidden", suite_contents)
        legacy = json.loads(generate_assetlib.render(self.root)["alpha.json"])
        self.assertEqual(legacy["zip"], "GodotDevTools-alpha-1.0.0.zip")

    def test_archives_do_not_depend_on_source_timestamps(self):
        first, second = self.work / "first", self.work / "second"
        build_archives.build(self.root, first, "v1.2.3")
        os.utime(self.root / "addons/alpha/plugin.cfg", (1700000000, 1700000000))
        build_archives.build(self.root, second, "v1.2.3")
        for original in first.glob("*.zip"):
            self.assertEqual(original.read_bytes(), (second / original.name).read_bytes(), original.name)

    def test_conflicting_license_and_symlinks_fail_before_publication(self):
        out = self.work / "dist"
        (self.root / "addons/alpha/LICENSE").write_text("different license")
        with self.assertRaisesRegex(release_manifest.ManifestError, "differs"):
            build_archives.build(self.root, out, "v1.2.3")
        self.assertFalse(out.exists())
        (self.root / "addons/alpha/LICENSE").unlink()
        link = self.root / "addons/alpha/other"
        try:
            link.symlink_to(self.root / "LICENSE")
        except (OSError, NotImplementedError):
            self.skipTest("symlinks unavailable")
        with self.assertRaisesRegex(release_manifest.ManifestError, "symlinks"):
            build_archives.build(self.root, out, "v1.2.3")
        self.assertFalse(out.exists())

    @unittest.skipUnless(os.name == "posix", "test creates POSIX-only conflicting names")
    def test_nonportable_and_case_colliding_paths_are_rejected(self):
        addon = self.root / "addons/alpha"
        bad = addon / "bad\\name.gd"
        bad.write_text("bad")
        with self.assertRaisesRegex(release_manifest.ManifestError, "non-portable archive path"):
            build_archives.build(self.root, self.work / "dist", "v1.2.3")
        bad.unlink()
        (addon / "CORE").write_text("conflicts with core directory on case-insensitive filesystems")
        with self.assertRaisesRegex(release_manifest.ManifestError, "case-insensitive archive path collision"):
            build_archives.build(self.root, self.work / "dist", "v1.2.3")

    def test_unreadable_subdirectory_fails_instead_of_omitting_files(self):
        def fail_walk(path, *, followlinks, onerror):
            onerror(PermissionError("synthetic unreadable directory"))
            return []

        out = self.work / "dist"
        with mock.patch.object(build_archives.os, "walk", side_effect=fail_walk):
            with self.assertRaisesRegex(release_manifest.ManifestError, "cannot read addon tree"):
                build_archives.build(self.root, out, "v1.2.3")
        self.assertFalse(out.exists())

    def test_existing_equal_license_is_not_duplicated(self):
        (self.root / "addons/alpha/LICENSE").write_bytes((self.root / "LICENSE").read_bytes())
        out = self.work / "dist"
        build_archives.build(self.root, out, "v1.2.3")
        with zipfile.ZipFile(out / "GodotDevTools-Alpha-v1.2.3.zip") as archive:
            self.assertEqual(archive.namelist().count("addons/alpha/LICENSE"), 1)

    def test_no_overwrite_inside_addons_or_partial_archive_on_error(self):
        out = self.work / "dist"
        out.mkdir()
        (out / "keep.txt").write_text("keep")
        with self.assertRaisesRegex(release_manifest.ManifestError, "absent or empty"):
            build_archives.build(self.root, out, "v1.2.3")
        self.assertEqual((out / "keep.txt").read_text(), "keep")
        with self.assertRaisesRegex(release_manifest.ManifestError, "inside addons"):
            build_archives.build(self.root, self.root / "addons/alpha/out", "v1.2.3")
        (out / "keep.txt").unlink()
        original = build_archives._write_archive
        calls = []

        def fail_second(path, entries):
            calls.append(path)
            if len(calls) == 2:
                raise OSError("simulated disk error")
            original(path, entries)

        with mock.patch.object(build_archives, "_write_archive", side_effect=fail_second):
            with self.assertRaisesRegex(OSError, "simulated disk error"):
                build_archives.build(self.root, out, "v1.2.3")
        self.assertEqual(list(out.iterdir()), [])
        self.assertEqual(list(self.work.glob(".gdt-release-*")), [])

    def test_install_smoke_rejects_archive_path_traversal(self):
        malicious = self.work / "malicious.zip"
        with zipfile.ZipFile(malicious, "w") as archive:
            archive.writestr("addons/../../escape.txt", "bad")
        project = self.work / "project"
        project.mkdir()
        with self.assertRaisesRegex(release_install_smoke.SmokeFailure, "unsafe archive path"):
            release_install_smoke.extract_checked(malicious, project)
        self.assertFalse((self.work / "escape.txt").exists())

    def test_metadata_output_guard_and_stale_detection(self):
        outputs = generate_assetlib.render(self.root)
        out = self.work / "metadata"
        out.mkdir()
        (out / "README.md").write_text("user document")
        with self.assertRaisesRegex(release_manifest.ManifestError, "previously generated"):
            generate_assetlib.write_outputs(self.root, out, outputs)
        self.assertEqual((out / "README.md").read_text(), "user document")
        (out / "README.md").unlink()
        generate_assetlib.write_outputs(self.root, out, outputs)
        self.assertEqual(generate_assetlib.check_outputs(out, outputs), [])
        (out / "alpha.json").write_text("stale")
        (out / "removed.json").write_text("{}")
        problems = generate_assetlib.check_outputs(out, outputs)
        self.assertTrue(any("out of date" in problem and "alpha.json" in problem for problem in problems))
        self.assertTrue(any("unexpected metadata" in problem and "removed.json" in problem for problem in problems))

    def test_metadata_does_not_follow_output_symlinks(self):
        outputs = generate_assetlib.render(self.root)
        out = self.work / "metadata"
        generate_assetlib.write_outputs(self.root, out, outputs)
        outside = self.work / "outside.txt"
        outside.write_text("do not overwrite")
        (out / "alpha.json").unlink()
        try:
            (out / "alpha.json").symlink_to(outside)
        except (OSError, NotImplementedError):
            self.skipTest("symlinks unavailable")
        with self.assertRaisesRegex(release_manifest.ManifestError, "non-regular metadata"):
            generate_assetlib.write_outputs(self.root, out, outputs)
        self.assertEqual(outside.read_text(), "do not overwrite")


@unittest.skipUnless(os.name == "posix", "fake executable smoke harness requires POSIX")
class InstallSmokeHarnessTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="gdt-install-harness-")
        work = Path(self.temp.name)
        self.fake = work / "fake-godot"
        self.fake.write_text(FAKE_GODOT, encoding="utf-8")
        self.fake.chmod(0o755)
        self.trace = work / "trace.jsonl"

    def tearDown(self):
        self.temp.cleanup()

    def test_both_archive_variants_run_the_expected_commands(self):
        env = {"GDT_FAKE_TRACE": str(self.trace), "GDT_FAKE_SCRIPT_ERROR": ""}
        with mock.patch.dict(os.environ, env, clear=False), contextlib.redirect_stdout(io.StringIO()):
            release_install_smoke.run_smoke(self.fake)
        calls = [json.loads(line) for line in self.trace.read_text().splitlines()]
        self.assertEqual(len(calls), 6)
        self.assertEqual(sum(any("export_clean.cfg" in arg for arg in call) for call in calls), 2)
        self.assertEqual(sum(any("export_presets.cfg" in arg for arg in call) for call in calls), 2)
        self.assertEqual(sum(any("missing.cfg" in arg for arg in call) for call in calls), 2)

    def test_script_errors_are_not_hidden_by_a_zero_exit(self):
        with mock.patch.dict(os.environ, {"GDT_FAKE_TRACE": str(self.trace), "GDT_FAKE_SCRIPT_ERROR": "1"}, clear=False):
            with self.assertRaisesRegex(release_install_smoke.SmokeFailure, "script error"):
                release_install_smoke.run_smoke(self.fake)


class RepositoryReleaseTests(unittest.TestCase):
    def test_historical_stems_and_complete_manifest(self):
        manifest = release_manifest.load_manifest(ROOT)
        for folder, stem in {
            "bt_debugger": "BTDebugger", "golden_snapshot": "GoldenSnapshots",
            "spawn_validator": "SpawnPoints", "android_export_audit": "AndroidExportAudit",
            "android_touch_audit": "AndroidTouchAudit", "android_logcat_triage": "AndroidLogcatTriage",
        }.items():
            self.assertEqual(manifest[folder], stem)
        self.assertEqual(set(manifest), {p.name for p in (ROOT / "addons").iterdir() if p.is_dir()})

    def test_checked_in_metadata_is_current(self):
        result = subprocess.run([sys.executable, str(ROOT / "tools/assetlib/generate_assetlib.py"), "--check"],
                                capture_output=True, text=True, timeout=30, check=False)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_tagged_cli_honors_output_directory_and_check(self):
        with tempfile.TemporaryDirectory(prefix="gdt-meta-test-") as tmp:
            out = Path(tmp) / "metadata with spaces"
            command = [sys.executable, str(ROOT / "tools/assetlib/generate_assetlib.py"),
                       "--release-tag", "v9.8.7", "--out", str(out)]
            result = subprocess.run(command, cwd=tmp, capture_output=True, text=True, timeout=30, check=False)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            data = json.loads((out / "android_export_audit.json").read_text())
            self.assertEqual(data["zip"], "GodotDevTools-AndroidExportAudit-v9.8.7.zip")
            self.assertEqual(data["version"], "1.0.0")
            result = subprocess.run(command + ["--check"], cwd=tmp, capture_output=True, text=True, timeout=30, check=False)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            (out / "android_export_audit.json").write_text("{}")
            result = subprocess.run(command + ["--check"], cwd=tmp, capture_output=True, text=True, timeout=30, check=False)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("out of date", result.stderr)

    def test_packaging_cli_builds_and_rejects_invalid_tags(self):
        script = ROOT / "tools/release/build_archives.py"
        with tempfile.TemporaryDirectory(prefix="gdt-build-cli-") as tmp:
            out = Path(tmp) / "release output"
            command = [sys.executable, str(script), "--tag", "v0.0.0", "--out", str(out)]
            result = subprocess.run(command, cwd=tmp, capture_output=True, text=True, timeout=30, check=False)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertTrue((out / "GodotDevTools-AndroidExportAudit-v0.0.0.zip").is_file())
            self.assertTrue((out / "GodotDevTools-Suite-v0.0.0.zip").is_file())
            result = subprocess.run(command, cwd=tmp, capture_output=True, text=True, timeout=30, check=False)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("absent or empty", result.stderr)
            invalid_out = Path(tmp) / "invalid"
            result = subprocess.run([sys.executable, str(script), "--tag", "v1.2.3/../bad", "--out", str(invalid_out)],
                                    cwd=tmp, capture_output=True, text=True, timeout=30, check=False)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("invalid release tag", result.stderr)
            self.assertFalse(invalid_out.exists())

    def test_every_real_archive_matches_source_and_tagged_metadata(self):
        manifest = release_manifest.load_manifest(ROOT)
        outputs = generate_assetlib.render(ROOT, "v9.8.7")
        license_bytes = (ROOT / "LICENSE").read_bytes()
        with tempfile.TemporaryDirectory(prefix="gdt-real-release-") as tmp:
            out = Path(tmp) / "dist"
            self.assertEqual(build_archives.build(ROOT, out, "v9.8.7"), len(manifest))
            self.assertEqual(len(list(out.glob("*.zip"))), len(manifest) + 1)
            suite_contents = {}
            for folder in manifest:
                metadata = json.loads(outputs[f"{folder}.json"])
                path = out / metadata["zip"]
                self.assertTrue(path.is_file(), path)
                source = ROOT / "addons" / folder
                expected = {p.relative_to(ROOT).as_posix(): p.read_bytes() for p in source.rglob("*") if p.is_file()}
                expected[f"addons/{folder}/LICENSE"] = license_bytes
                with zipfile.ZipFile(path) as archive:
                    self.assertEqual(len(archive.namelist()), len(set(archive.namelist())), path.name)
                    self.assertEqual(set(archive.namelist()), set(expected), path.name)
                    for name, content in expected.items():
                        self.assertEqual(archive.read(name), content, name)
                suite_contents.update(expected)
            with zipfile.ZipFile(out / "GodotDevTools-Suite-v9.8.7.zip") as archive:
                self.assertEqual(len(archive.namelist()), len(set(archive.namelist())))
                self.assertEqual(set(archive.namelist()), set(suite_contents))
                for name, content in suite_contents.items():
                    self.assertEqual(archive.read(name), content, name)


if __name__ == "__main__":
    unittest.main(verbosity=2)
