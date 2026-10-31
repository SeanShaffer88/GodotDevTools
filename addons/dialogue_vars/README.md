# Dialogue Variable Lint

Find dialogue variables that conditions read but nothing sets, and variables effects set but nothing reads. Enable the addon in Project Settings → Plugins and use **Lint dialogue variables** in the **Dialogue Vars** dock.

It reads every `.json` under the folder (hidden folders, `addons/` and report folders skipped) that contains `"dialogues"` or `"quests"`, in the Dialogue and Quest Debugger format: each choice may carry a `condition` (`{"var", "op", "value"}` or a list of them) and `effects` (`{"var": value}`). Variables that conditions read are compared with variables that effects set.

| Finding | Meaning |
|---|---|
| `read_never_set` | A condition reads a variable that no effect sets and that is not listed in `--external`. |
| `set_never_read` | An effect sets a variable that no condition reads. |
| `type_mismatch` | A variable is compared with one type and set with another (int and float count as one). |

## Command line

```sh
godot --headless --path . --script res://addons/dialogue_vars/cli/dvl_cli.gd -- \
  --dir=res://demo/dialogue --fail-on=read_never_set
```

Options: `--dir=<path>` (default `res://`), `--out=<dir>` (default `res://reports/dialogue_vars`), `--external` (comma-separated variables set by game code, not dialogue), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `dialogue_vars.json` and `dialogue_vars.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- Variables set or read by game code are invisible; declare the ones game code sets with `--external`.
- Only the documented JSON format is read; other dialogue formats need converting first.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
