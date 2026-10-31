# Android Permissions Reviewer

List the permissions each Android export preset requests, flag commonly sensitive ones for review, and check each has a written justification. Enable the addon in Project Settings → Plugins and use **Review permissions** in the **Android Permissions** dock.

It reads `export_presets.cfg` (or `--presets`), finds presets with `platform="Android"`, and lists every `permissions/<name>=true` option plus the entries of `permissions/custom_permissions`. Permissions on a built-in list of commonly sensitive ones (camera, microphone, location, contacts, SMS, phone, body sensors, storage and media, calendar, activity recognition, overlay, package install) are flagged for review. With `--justifications=<json>` (`{"CAMERA": "AR photo mode"}`) every requested permission must have a written reason.

| Finding | Meaning |
|---|---|
| `sensitive_permission` | A commonly sensitive permission is requested. |
| `unjustified_permission` | A permission has no entry in the justifications file. |
| `no_android_preset` | No Android preset exists. |

## Command line

```sh
godot --headless --path . --script res://addons/android_permissions/cli/apr_cli.gd -- \
  --presets=res://demo/shipping/android_presets.cfg --fail-on=sensitive_permission
```

Options: `--presets=<path>` (default `res://export_presets.cfg`), `--out=<dir>` (default `res://reports/android_permissions`), `--justifications` (JSON {PERMISSION: reason}; when given, permissions without a reason are reported), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `android_permissions.json` and `android_permissions.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- Review aid, not a policy check: store and platform rules change; the sensitive list is a starting point.
- Permissions added by Android plugins or a custom Gradle build manifest are not read.
- It does not check that the game requests permissions at runtime.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
