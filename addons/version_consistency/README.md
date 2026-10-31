# Version Consistency Checker

Compare the project version with every version string in the export presets and report mismatches. Enable the addon in Project Settings → Plugins and use **Check versions** in the **Version Check** dock.

It reads `application/config/version` from the project file (or uses `--expected`) and compares it with each export preset's `version/name`, `application/version`, `application/short_version`, `application/file_version` and `application/product_version`. Trailing `.0` parts are ignored, so `1.2.0` matches `1.2.0.0`. Android `version/code` values are listed in the report but not compared.

| Finding | Meaning |
|---|---|
| `version_mismatch` | A preset reports a different version. |
| `missing_version` | No project version, or a preset leaves a version field empty. |

## Command line

```sh
godot --headless --path . --script res://addons/version_consistency/cli/vcc_cli.gd -- \
  --project=res://demo/shipping/version_project.godot --presets=res://demo/shipping/android_presets.cfg --fail-on=version_mismatch
```

Options: `--project=<path>` (default `res://project.godot`), `--out=<dir>` (default `res://reports/version_consistency`), `--presets` (export presets file (default res://export_presets.cfg)), `--expected` (version to expect instead of the project's config/version), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `version_consistency.json` and `version_consistency.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- Version strings inside code, splash screens or store listings are not checked.
- Android version codes must increase per upload; that needs your release history and is not checked.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
