# Input Sequence Fuzzer

Generate seeded, bounded input-action sequences from the project's InputMap, and replay them in game with a runtime player node. Enable the addon in Project Settings → Plugins and use **Generate sequences** in the **Input Fuzzer** dock.

It reads action names from the `[input]` section of the project file (built-in `ui_*` actions are skipped unless `--include-ui`) and generates `--sequences` sequences of `--length` steps. Each step is `{frame, action, hold}`: the action is pressed on `frame` and released `hold` frames later. Generation is seeded (`--seed`), so a failing sequence can be regenerated exactly. The sequences are in the JSON report.

To replay one, add `runtime/isf_player.gd` to a test scene, call `play(sequence)` with an entry of the report's `sequences` array, and watch for crashes, errors or stuck states; it emits `finished` when done.

| Finding | Meaning |
|---|---|
| `unbound_action` | An action has no input events, so players cannot trigger it. |
| `no_actions` | Nothing bound to fuzz (exit 1). |

## Command line

```sh
godot --headless --path . --script res://addons/input_fuzzer/cli/isf_cli.gd -- \
  --project=res://demo/ci/input_actions.godot --fail-on=unbound_action
```

Options: `--project=<path>` (default `res://project.godot`), `--out=<dir>` (default `res://reports/input_fuzzer`), `--seed` (random seed (default 1)), `--sequences` (number of sequences (default 5)), `--length` (steps per sequence (default 60)), `--max-hold` (longest hold in frames (default 30)), `--include-ui` (include built-in ui_* actions (default false)), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `input_fuzzer.json` and `input_fuzzer.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- Actions are pressed as InputEventAction (full strength); analog values and mouse motion are not generated.
- The fuzzer finds crashes and stuck states only if your scene or assertions surface them; it does not judge gameplay.
- The runtime player is covered by unit tests of its scheduling; a live game session is pending.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
