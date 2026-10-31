# Texture Atlas Packing Planner

Shelf-pack sprite sizes into atlas pages and report page count, waste and sprites that cannot fit. Enable the addon in Project Settings → Plugins and use **Plan atlas** in the **Atlas Planner** dock.

Input is either a folder of PNG files (sizes read from their headers) or a JSON file:

```json
{"page_size": 256, "padding": 2, "sprites": [{"name": "tile0", "w": 64, "h": 64}]}
```

Sprites are sorted by height and placed left to right on shelves of square pages with `padding` pixels between them. The report lists pages, waste (empty share of all page area) and each sprite's page and position.

| Finding | Meaning |
|---|---|
| `sprite_too_big` | A sprite is larger than a page. |
| `page_budget` | More pages than `--max-pages`. |
| `high_waste` | Empty page area above `--max-waste`. |

## Command line

```sh
godot --headless --path . --script res://addons/atlas_planner/cli/atp_cli.gd -- \
  --input=res://demo/assets_audit/atlas.json --fail-on=sprite_too_big
```

Options: `--input=<path>` (default `res://demo/assets_audit/atlas.json`), `--out=<dir>` (default `res://reports/atlas_planner`), `--page-size` (square page size in pixels (default 2048; a JSON file may set its own)), `--padding` (pixels between sprites (default 2)), `--max-pages` (page budget (default 4)), `--max-waste` (flag waste above this share (default 0.5)), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `atlas_planner.json` and `atlas_planner.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- Shelf packing without rotation or alpha trimming: an upper bound on pages compared with MaxRects packers.
- No atlas image or AtlasTexture resources are written; this plans, it does not pack.
- The last page counts fully toward waste.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
