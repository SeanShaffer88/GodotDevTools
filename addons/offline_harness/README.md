# Offline and Poor-Connection Test Harness

Find HTTP requests with no timeout or unchecked results, and simulate offline, timeout, slow and server-error responses in game with a seeded fault profile. Enable the addon in Project Settings → Plugins and use **Check offline handling** in the **Offline Harness** dock.

Static checks over scripts and scenes under the folder: `HTTPRequest` scene nodes with no `timeout` (default 0 waits forever), scripts that create `HTTPRequest` without setting `.timeout`, and functions connected to `request_completed` that never read the result or response code.

Runtime: replace `HTTPRequest` with `runtime/ocn_http.gd` in test builds (same `request()` and `request_completed`) and give it a profile:

```json
{"seed": 3, "rules": [
  {"match": "api.example.com/scores", "fault": "offline"},
  {"match": "api.example.com/news", "fault": "timeout", "rate": 0.5},
  {"match": "*", "fault": "slow", "delay_ms": 1500, "rate": 0.25}]}
```

Faults: `offline` (RESULT_CANT_CONNECT), `timeout` (RESULT_TIMEOUT after the node's timeout), `slow` (real request after `delay_ms`), `http_error` (RESULT_SUCCESS with `status`, default 500). The first matching rule whose `rate` roll succeeds applies; rolls are seeded per seed, request number and URL, so runs replay exactly. `--profile` validates a profile and previews the first five decisions for every URL found.

| Finding | Meaning |
|---|---|
| `no_timeout` | A request that can wait forever. |
| `unhandled_result` | A completion handler that ignores failures. |
| `bad_profile` | Profile missing or malformed (exit 1). |

## Command line

```sh
godot --headless --path . --script res://addons/offline_harness/cli/ocn_cli.gd -- \
  --dir=res://demo/privacy --fail-on=unhandled_result
```

Options: `--dir=<path>` (default `res://`), `--out=<dir>` (default `res://reports/offline_harness`), `--profile` (fault profile JSON to validate and preview against the URLs found), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `offline_harness.json` and `offline_harness.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- Only HTTPRequest flows; raw sockets, WebSockets and multiplayer peers are not shimmed (use the Multiplayer Network Simulator for game traffic).
- Static handler detection follows `request_completed.connect(handler)` in the same script.
- The runtime node is unit-tested for its decisions; a live networked session is pending.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
