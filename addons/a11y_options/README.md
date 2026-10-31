# Accessibility Options Coverage

Look for evidence of expected player accessibility options (subtitles, remapping, text size, colour-blind modes, reduced motion, mono audio, hold/toggle) in project files. Enable the addon in Project Settings → Plugins and use **Check option coverage** in the **A11y Options** dock.

It searches `.gd`, `.tscn`, `.tres`, `.json`, `.cfg` and `.csv` files under the folder for keyword patterns of each expected option and records the first place it finds each. Built-in list: subtitles/captions, control remapping, text size/UI scale, colour-blind modes, reduced motion/screen shake, mono audio, hold-to-toggle. Replace it with `--expect=<json>`:

```json
[{"id": "big_cursor", "label": "Large cursor", "patterns": ["big_?cursor", "cursor_?size"]}]
```

| Finding | Meaning |
|---|---|
| `option_not_found` | No file matches any pattern of an expected option. |

## Command line

```sh
godot --headless --path . --script res://addons/a11y_options/cli/aoc_cli.gd -- \
  --dir=res://demo/shipping --fail-on=option_not_found
```

Options: `--dir=<path>` (default `res://`), `--out=<dir>` (default `res://reports/a11y_options`), `--expect` (JSON file replacing the built-in expected-options list), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `a11y_options.json` and `a11y_options.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- Keyword evidence only: a match does not prove the option works, and an option under an unusual name is missed.
- The built-in list is a common starting set, not a standard; adapt it to your game and audience.
- Pair with the Automated Accessibility Checker and testing with players who use these options.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
