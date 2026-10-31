# Privacy and Permissions Auditor

Inventory everything in a project that touches the network, device identifiers, the clipboard, the microphone or camera, or opens external links, for privacy review. Enable the addon in Project Settings → Plugins and use **Audit privacy surface** in the **Privacy Audit** dock.

It reads scripts (GDScript and C#), scenes, resources and settings under the folder (hidden folders, `addons/` and report folders skipped) and lists, with file and line: http(s)/ws(s) URL strings (each distinct endpoint once); network classes; device identifiers (`OS.get_unique_id`, model/processor name, environment variables, screen queries); clipboard access; microphone input (`AudioStreamMicrophone`, capture/record effects, `audio/driver/enable_input=true`); camera (`CameraServer`, `CameraFeed`); and `OS.shell_open`. Pair the inventory with the Android Permissions Reviewer and your privacy policy.

| Finding | Meaning |
|---|---|
| `network_endpoint` | A URL the project may contact. |
| `network_api` | A networking class in use. |
| `device_identifier` | A device/user identifier read. |
| `clipboard` | Clipboard access. |
| `microphone` | Microphone input. |
| `camera` | Camera access. |
| `external_open` | `OS.shell_open` use. |

## Command line

```sh
godot --headless --path . --script res://addons/privacy_audit/cli/ppa_cli.gd -- \
  --dir=res://demo/privacy --fail-on=device_identifier
```

Options: `--dir=<path>` (default `res://`), `--out=<dir>` (default `res://reports/privacy_audit`), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `privacy_audit.json` and `privacy_audit.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- Inventory for review, not a legal assessment or a policy check.
- Third-party SDKs in native plugins and URLs built at runtime are not seen.
- Saving data locally (`user://`) is not listed; review saves separately.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
