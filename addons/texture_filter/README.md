# Texture Filter Consistency Checker

Check pixel-art textures for mipmaps and lossy compression, and the project's default canvas filter. Enable the addon in Project Settings → Plugins and use **Check texture filters** in the **Texture Filter** dock.

It reads every texture `.import` file under the folder (hidden folders, `addons/` and report folders skipped). Textures whose path contains `--pixel-pattern` (default `/pixel`) are treated as pixel art and must not generate mipmaps or use lossy compression. When any pixel art exists, the project's default canvas texture filter (Linear when unset) is reported unless it is Nearest.

| Finding | Meaning |
|---|---|
| `pixel_mipmaps` | A pixel-art texture generates mipmaps. |
| `pixel_lossy` | A pixel-art texture uses Lossy, VRAM Compressed or Basis Universal compression. |
| `filter_default_linear` | Pixel art exists but the default canvas texture filter is not Nearest. |

## Command line

```sh
godot --headless --path . --script res://addons/texture_filter/cli/tfc_cli.gd -- \
  --dir=res://demo/assets_audit --fail-on=pixel_mipmaps
```

Options: `--dir=<path>` (default `res://`), `--out=<dir>` (default `res://reports/texture_filter`), `--pixel-pattern` (path text marking pixel art (default /pixel)), `--project` (project file for the default canvas filter (default res://project.godot)), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `texture_filter.json` and `texture_filter.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- Pixel art is identified only by path pattern.
- Per-node `texture_filter` overrides and 3D material sampler settings are not read.
- The reverse case (smooth art forced to Nearest) is not checked.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
