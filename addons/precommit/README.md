# Pre-commit Hook Installer

Generate an opt-in git pre-commit hook that runs chosen tool CLIs, and install or remove it without touching hooks it did not write. Enable the addon in Project Settings → Plugins and use **Preview hook** in the **Pre-commit Hook** dock.

Config:

```json
[{"tool": "node_paths", "args": "--fail-on=broken_path"}, {"tool": "scene_lint", "args": "--fail-on=rule_violation"}]
```

Without flags the CLI only writes the generated hook to `reports/precommit/pre-commit` for review. `--install` writes it to `<git dir>/hooks/pre-commit` (default `res://.git`) and makes it executable; `--uninstall` removes it. A hook not written by this tool (no marker line) is never overwritten or removed. The hook runs each CLI through `$GODOT` (default `godot`) and blocks the commit if any fails; `git commit --no-verify` skips it once.

| Finding | Meaning |
|---|---|
| `foreign_hook` | Another pre-commit hook exists; left untouched (exit 1). |
| `unknown_tool` | A configured tool has no CLI. |
| `no_git_dir` | The git folder was not found (exit 1). |
| `bad_config` | Config missing or malformed (exit 1). |

## Command line

```sh
godot --headless --path . --script res://addons/precommit/cli/pch_cli.gd -- \
  --config=res://demo/suite/precommit.json
```

Options: `--config=<path>` (default `res://demo/suite/precommit.json`), `--out=<dir>` (default `res://reports/precommit`), `--install` (write the hook into the git hooks folder), `--uninstall` (remove a hook this tool installed), `--git-dir` (the repository's .git folder (default res://.git)), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `precommit.json` and `precommit.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- POSIX sh hook: on Windows it runs under Git for Windows' shell; set GODOT to your Godot executable path.
- Checks run on the working tree, not only staged changes.
- Opt-in and local: each developer installs it; CI should still run the gates.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
