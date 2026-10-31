# Art-to-Engine Handoff Validator

Check glTF/GLB exports for unapplied scale, implausible sizes, default material and animation names, missing UVs and unknown import suffixes. Enable the addon in Project Settings → Plugins and use **Validate art handoff** in the **Art Handoff** dock.

It reads every `.gltf`/`.glb` under the folder (hidden folders, `addons/` and report folders skipped) and checks: node `scale` other than 1 (unapplied in the DCC tool); each mesh node's extent (POSITION min/max × scale) against `--min-size`/`--max-size` metres; default material and animation names (`Material.001`, `Action`, `ArmatureAction`, `lambert1`, ...); textured materials on primitives without `TEXCOORD_0`; and node names ending in something that looks like a Godot import hint (`-col`, `-colonly`, `-convcolonly`, `-navmesh`, `-occ`, `-loop`, ...) but is not one.

| Finding | Meaning |
|---|---|
| `unapplied_scale` | Node scale is not 1. |
| `size_suspect` | Extent outside the plausible range (units?). |
| `default_name` | DCC default material/animation name. |
| `missing_uv` | Textured material, no UVs. |
| `unknown_suffix` | Misspelt import hint suffix. |
| `bad_gltf` | Not readable glTF. |

## Command line

```sh
godot --headless --path . --script res://addons/art_handoff/cli/aeh_cli.gd -- \
  --dir=res://demo/workflow/handoff --fail-on=unapplied_scale
```

Options: `--dir=<path>` (default `res://`), `--out=<dir>` (default `res://reports/art_handoff`), `--min-size` (smallest plausible model extent in metres (default 0.05)), `--max-size` (largest plausible model extent in metres (default 500)), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `art_handoff.json` and `art_handoff.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- glTF/GLB only; export from Blender/Maya/Max to glTF to check (FBX and .blend are not parsed).
- Sizes use node scale only, not parent transforms.
- Orientation and pivot placement need a human look in the engine.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
