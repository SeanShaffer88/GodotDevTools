# Crash and Error Reproduction Packager

Bundle a redacted log, engine and system details and reproduction steps into one local package for a bug report. Nothing is uploaded. Enable the addon in Project Settings → Plugins and use **Build package preview** in the **Crash Packager** dock.

It reads the tail of a log (default `user://logs/godot.log`, written when Project Settings → Debug → File Logging is on), the reproduction steps you pass with `--steps`, and engine/OS details (Godot version, OS and version, CPU, locale, renderer, project name and version). E-mail addresses, IPv4 addresses, `token=`/`api_key=`/`password=`-style values and user names in home-folder paths are replaced before anything is written. The CLI writes `log_redacted.txt`, `steps.txt`, `system.json` and `manifest.json` next to its report and, with `--zip=<path>`, a zip of all four. Add it to an in-game "report a bug" button by calling the core from your own UI.

| Finding | Meaning |
|---|---|
| `missing_log` | No log at the given path. |
| `redacted` | How many items were redacted, by type. |
| `log_truncated` | Only the end of a long log was kept. |

## Command line

```sh
godot --headless --path . --script res://addons/crash_packager/cli/crp_cli.gd -- \
  --log=res://demo/testing/crash/godot.log --steps=res://demo/testing/crash/steps.txt
```

Options: `--log=<path>` (default `user://logs/godot.log`), `--out=<dir>` (default `res://reports/crash_packager`), `--steps` (text file with reproduction steps), `--zip` (also write all package files into this .zip path), `--max-log-bytes` (keep at most this many bytes from the end of the log (default 200000)), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `crash_packager.json` and `crash_packager.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- Pattern-based redaction misses personal data in other shapes (names in chat logs, custom IDs); always review before sharing.
- Crash dumps and native stack traces are not collected.
- No network code: sending the package is up to you or your player.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
