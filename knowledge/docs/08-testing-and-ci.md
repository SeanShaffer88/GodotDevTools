# 08 — Testing and CI

## On a real device: one-click deploy

From the official One-click deploy docs: mark an Android export
preset **Runnable**, enable USB debugging on the device, and the
editor exports, installs, and runs a **debug build** in one step.
Wireless ADB works too. Remember the signing trap from docs/03:
same package name with a different key already installed means
uninstall first.

## Automated tests: Godot ships no framework

There is no built-in project test framework; the community
standards are both headless-capable:

| Framework | Version (Nov 2026) | Headless invocation |
|---|---|---|
| GUT (bitwes/Gut) | v9.7.1, targets Godot 4.7.x | `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit` |
| GdUnit4 (godot-gdunit-labs/gdUnit4) | v6.2.3; ships its own GitHub Action | `GdUnitCmdTool.gd` — exits **103** unless `--ignoreHeadlessMode` is passed; test failures exit **100** |

Two traps, both confirmed on Godot 4.7.2:

1. **Headless mode does not deliver input events to Controls.**
   UI click tests need a virtual display (`xvfb-run`) instead of
   `--headless`.
2. **Both runners can exit 0 when zero tests ran.** A CI gate that
   only checks the exit code can pass an empty suite forever —
   assert the executed-test count in the report.

## CI builds: the godot-ci route

- **abarichello/godot-ci** is the community-standard route: Docker
  images (`barichello/godot-ci`) track Godot releases (a 4.7.1 tag
  was current in Nov 2026), in standard and `mono-` variants,
  bundling the Android SDK and a debug keystore, with example
  GitHub Actions and GitLab CI workflows. **iOS export is not
  supported.** No official Godot-org GitHub Action was found.
- Keystore credentials reach the export through the
  `GODOT_ANDROID_KEYSTORE_*` environment variables (docs/03) —
  CI secrets, never repo files.
- Treat the images' exact bundled SDK components as unverified
  (published lists look dated); if a build fails on a component,
  pin your own SDK install step rather than trusting the image's.
