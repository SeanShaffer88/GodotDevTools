# Unused Signal and Method Finder

Find declared signals that are never emitted or connected, and functions nothing references. Enable the addon in Project Settings → Plugins and use **Find unused symbols** in the **Unused Symbols** dock.

It collects `signal` and `func` declarations from every `.gd` file under the folder (hidden folders, `addons/` and report folders skipped) and counts how often each name appears as a whole word anywhere in `.gd`, `.tscn` and `.tres` text, including scene `[connection]` entries and string calls such as `call("name")`. Engine callbacks (`_ready`, `_process`, ...) are never flagged.

| Finding | Meaning |
|---|---|
| `never_emitted` | A signal has no `.emit(` or `emit_signal("name")` anywhere. |
| `never_connected` | A signal is emitted, but nothing connects to it or mentions it elsewhere. |
| `unused_function` | A function name appears nowhere except its own declaration. |

## Command line

```sh
godot --headless --path . --script res://addons/unused_symbols/cli/usf_cli.gd -- \
  --dir=res://demo/code_health --fail-on=never_emitted
```

Options: `--dir=<path>` (default `res://`), `--out=<dir>` (default `res://reports/unused_symbols`), `--include-private` (also check functions whose names start with `_` (default true)), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `unused_symbols.json` and `unused_symbols.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- Word matching, not symbol resolution: two unrelated functions with the same name hide each other, so misses are possible but flagged items are strong candidates.
- Names built at runtime (`call("do_" + action)`) are invisible, and public API used by other projects or plugins is flagged; review before deleting.
- Use `--include-private=false` to skip functions starting with `_`.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
