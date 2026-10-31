# Colour Palette Consistency Checker

Compare every Color(...) and #hex colour in scenes, resources and scripts with an approved palette using CIE delta E. Enable the addon in Project Settings → Plugins and use **Check palette** in the **Palette Check** dock.

Palette file:

```json
{"colors": ["#1d2b53", "#7e2553", "#008751", "#ffa300", "#fff1e8"], "max_delta_e": 6.0, "ignore": ["#ffffff", "#000000"]}
```

It reads every `.tscn`, `.tres` and `.gd` under the folder (hidden folders, `addons/` and report folders skipped), collects `Color(r, g, b[, a])` literals and quoted `"#rrggbb"` strings, converts them to CIELAB (sRGB, D65) and reports any whose CIE76 delta E to the nearest palette colour exceeds `max_delta_e` (about 2.3 is a just-noticeable difference).

| Finding | Meaning |
|---|---|
| `off_palette` | A colour is further than `max_delta_e` from every palette colour. |
| `bad_palette` | The palette file is missing or malformed (exit 1). |

## Command line

```sh
godot --headless --path . --script res://addons/palette_check/cli/pcc_cli.gd -- \
  --dir=res://demo/rendering --palette=res://demo/rendering/palette.json --fail-on=off_palette
```

Options: `--dir=<path>` (default `res://`), `--out=<dir>` (default `res://reports/palette_check`), `--palette` (palette JSON (default res://palette.json)), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `palette_check.json` and `palette_check.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- Colours computed in code, named constants (`Color.RED`) and texture pixels are not checked.
- CIE76 is a simple distance; it over-weights saturated colours compared with newer formulas.
- Alpha is ignored except that fully transparent colours are skipped.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
