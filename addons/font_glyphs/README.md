# Font Glyph Coverage Checker

Check every character used in translation CSV/PO files against a font's cmap table, per locale. Enable the addon in Project Settings → Plugins and use **Check glyph coverage** in the **Font Glyphs** dock.

It parses the font's `cmap` table (format 12 full-Unicode and format 4 BMP subtables) and collects the characters used by every locale column of translation `.csv` files (first row is the header, first column the key) and the `msgstr` text of `.po` files under `--strings` (default `res://`). For each locale it lists the characters the font cannot draw.

| Finding | Meaning |
|---|---|
| `missing_glyphs` | A locale uses characters the font does not map (first 20 shown, with code points). |
| `bad_font` | The font is missing or has no readable cmap (exit 1). |

## Command line

```sh
godot --headless --path . --script res://addons/font_glyphs/cli/fgc_cli.gd -- \
  --font=res://demo/assets_audit/ascii_only.ttf --strings=res://demo/assets_audit --fail-on=missing_glyphs
```

Options: `--font=<path>` (default `res://demo/assets_audit/ascii_only.ttf`), `--out=<dir>` (default `res://reports/font_glyphs`), `--strings` (folder scanned for translation .csv/.po files (default res://)), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `font_glyphs.json` and `font_glyphs.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- Single TrueType/OpenType fonts only; `.ttc` collections, WOFF/WOFF2 and system fonts are not read.
- Fallback fonts and theme font chains are not followed; check each fallback separately.
- Mapped is not the same as well drawn: a glyph that exists may still be a placeholder box.
- Multi-line `.po` msgstr continuations and CSV cells with embedded newlines are not read.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
