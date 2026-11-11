# Android Export Readiness Audit

Review Godot Android export presets for common release-configuration mistakes without exporting, reading keystores, or contacting a store. This complements Android Permissions Reviewer, Export Doctor and Version Consistency rather than replacing them.

## Install and use

Copy `addons/android_export_audit` into your project and enable **Android Export Readiness Audit** under Project → Project Settings → Plugins. In the **Android Export Audit** dock, choose an `export_presets.cfg` and optionally a history JSON, then press **Check Android presets**. Nothing in the preset is modified. The dock works on files supplied by the user; it does not perform an export.

The optional release history is a manually maintained object mapping the **exact configured package string** to its last released positive version code:

```json
{"com.studio.game": 42}
```

No store is queried. A code at or below that supplied value is flagged. `$genname` is treated as a valid placeholder for syntax checking; the tool does not resolve the generated application ID from the project name. History must use the exact preset value, so verify the actual exported application ID and release history yourself.

## Command line

```sh
godot --headless --path . --script res://addons/android_export_audit/cli/aea_cli.gd -- \
  --presets=res://export_presets.cfg --history=res://release_history.json \
  --fail-on=invalid_package,no_architecture,version_not_increased
```

`--presets` defaults to `res://export_presets.cfg`; `--history` is optional. `--out` defaults to `res://reports/android_export_audit`. JSON and Markdown reports are named `android_export_audit.json` and `android_export_audit.md`. `--fail-on` accepts comma-separated finding kinds below, `errors`, or `issues`. Exit **0** on success without selected findings, **2** if selected findings occur, and **1** for invalid arguments, unreadable/malformed inputs or report-write errors. `--help` lists the options. The preset and history files are limited to 2 MB each.

## Findings

| Kind | Meaning |
|---|---|
| `invalid_option`, `invalid_architecture` | A supported boolean option is not a boolean. |
| `no_architecture`, `arm32_without_arm64` | No ABI is enabled, or 32-bit ARM is enabled without arm64. Omitted ABI options use Godot 4.3 defaults. |
| `invalid_package`, `example_package` | Invalid identifier syntax or example namespace; placeholder expansion is assumed valid. |
| `invalid_version_code`, `version_not_increased`, `history_missing` | Invalid positive code, not above supplied history, or no entry for the exact preset value. |
| `invalid_format`, `bundle_requires_gradle`, `format_extension_mismatch`, `bundle_with_expansion` | Invalid APK/AAB selection, AAB without Gradle, a mismatched nonempty output path, or AAB with APK expansion. |
| `unsigned_package`, `embedded_password` | Signing disabled, or a nonempty debug/release password stored in this preset file. |
| `invalid_sdk`, `min_sdk_too_low`, `sdk_order`, `sdk_override_without_gradle` | Invalid SDK values, Godot 4.3 library minimum below 21, explicit target below the explicit/default minimum, or overrides without Gradle. |
| `no_android_preset` | No Android preset was found; informational. |
| `bad_input` | File or history is invalid/unreadable; always exits 1. |

## Limits and privacy

- Defaults and minimum SDK checks follow the **Godot 4.3** Android exporter; renderer-specific requirements, newer versions, export templates, Gradle plugins, manifest merges, actual AAB/APK contents and changing store policy are not verified. A clean report is not a shipping guarantee.
- Empty SDK overrides use exporter defaults. The order check compares an explicit target to an explicit minimum or Godot 4.3's default minimum of 24; it does not infer a store's current target requirement.
- Preset signing enabled does not prove a release is signed correctly. Credentials can be supplied through environment variables or private configuration; the tool neither reads those sources nor asserts that credentials are missing.
- Reports do not intentionally include stored password values, but preset/package names and file paths can be sensitive. Engine parse diagnostics and malformed input should also be treated as sensitive. Review reports and logs before sharing.
- The core and dock read inputs only; the CLI writes reports. No network calls are made. Headless fixture and CLI checks passed in the Godot 4.3/4.5 Linux and 4.3 Windows CI gates at commit `1678b02`; device exports and real-store submissions have not been validated by this addon.
