# Theme Resource Auditor

Find theme-override sprawl in scenes, too many distinct font sizes, near-duplicate sizes and unused theme type variations. Enable the addon in Project Settings → Plugins and use **Audit themes** in the **Theme Audit** dock.

It reads every `.tscn` and `.tres` under the folder (hidden folders, `addons/` and report folders skipped). It counts `theme_override_*` properties per scene, collects font sizes from overrides and Theme resources (including `default_font_size`), and lists Theme type variations (`Name/base_type = ...`) that no scene selects with `theme_type_variation`.

| Finding | Meaning |
|---|---|
| `override_sprawl` | A scene has more per-node theme overrides than `--max-overrides`. |
| `font_size_sprawl` | More distinct font sizes than `--max-font-sizes` across the folder. |
| `near_duplicate_sizes` | Two font sizes differ by 1 px. |
| `unused_variation` | A Theme type variation is never selected by a scanned scene. |

## Command line

```sh
godot --headless --path . --script res://addons/theme_audit/cli/tra_cli.gd -- \
  --dir=res://demo/rendering --fail-on=font_size_sprawl
```

Options: `--dir=<path>` (default `res://`), `--out=<dir>` (default `res://reports/theme_audit`), `--max-overrides` (theme overrides per scene (default 20)), `--max-font-sizes` (distinct font sizes across the project (default 6)), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `theme_audit.json` and `theme_audit.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- Variations selected from code (`theme_type_variation = ...` in scripts) are not seen.
- Font sizes set from code and LabelSettings resources are not read.
- Scan the whole project for reliable unused-variation results.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
