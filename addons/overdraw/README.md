# GPU Budget and Overdraw Analyzer

Estimate 2D overdraw per scene from sprite and rect sizes clipped to the screen, and fill-rate at target resolutions. Enable the addon in Project Settings → Plugins and use **Estimate overdraw** in the **Overdraw** dock.

For `Sprite2D` (texture size from the PNG header × `scale`, honouring `centered` and `position`) and `TextureRect`, `ColorRect`, `NinePatchRect` and `Panel` (from offsets) in each scene, it clips the drawn rectangle to a `--width` × `--height` screen and sums the areas. Overdraw is drawn area ÷ screen area; fill-rate is screen pixels × overdraw × `--fps`. Scenes are reported with their overdraw, full-screen layer count and fill-rate.

| Finding | Meaning |
|---|---|
| `overdraw_budget` | Estimated overdraw above `--max-overdraw`. |
| `stacked_fullscreen` | Three or more layers each cover at least 90% of the screen. |

## Command line

```sh
godot --headless --path . --script res://addons/overdraw/cli/gbo_cli.gd -- \
  --dir=res://demo/perf_static --fail-on=overdraw_budget
```

Options: `--dir=<path>` (default `res://`), `--out=<dir>` (default `res://reports/overdraw`), `--width` (screen width (default 1920)), `--height` (screen height (default 1080)), `--max-overdraw` (drawn area / screen area allowed (default 4.0)), `--fps` (frame rate for the fill-rate figure (default 60)), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `overdraw.json` and `overdraw.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- Estimate: rotation, parent transforms, cameras, transparency within textures, shaders, particles and text are not modelled.
- Fill-rate cost depends on the GPU; compare scenes with this figure and confirm with the profiler on target hardware.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
