# Rendering Settings Compatibility Matrix

List rendering nodes and environment features a project uses and flag those the chosen renderer does not implement, from an editable matrix. Enable the addon in Project Settings → Plugins and use **Check renderer support** in the **Render Compat** dock.

It records where scenes and resources under the folder use rendering nodes (`VoxelGI`, `LightmapGI`, `FogVolume`, `ReflectionProbe`, `Decal`, `GPUParticles3D` and its collision/attractor nodes, `WorldEnvironment`, `OccluderInstance3D`) and Environment flags (`sdfgi`, `ssr`, `ssao`, `ssil`, `volumetric_fog`, `glow`, `fog`). Features listed as unsupported for the project renderer (or `--renderer`) are flagged.

The built-in matrix lists only Compatibility-renderer gaps this project is confident of for Godot 4.3 (VoxelGI, FogVolume, SDFGI, SSR, SSAO, SSIL, volumetric fog). Supply your own with `--matrix=<json>`, for example `{"mobile": ["VoxelGI"], "gl_compatibility": ["VoxelGI", "Decal"]}`, taken from the renderer comparison in the Godot documentation for your version.

| Finding | Meaning |
|---|---|
| `unsupported_feature` | A used feature is listed as unsupported for the renderer. |
| `bad_matrix` | The matrix file is missing or malformed (exit 1). |

## Command line

```sh
godot --headless --path . --script res://addons/render_compat/cli/rcm_cli.gd -- \
  --dir=res://demo/perf_static --renderer=gl_compatibility --fail-on=unsupported_feature
```

Options: `--dir=<path>` (default `res://`), `--out=<dir>` (default `res://reports/render_compat`), `--renderer` (forward_plus, mobile or gl_compatibility (default: read from project.godot)), `--matrix` (JSON {renderer: [unsupported feature names]} replacing the built-in matrix), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `render_compat.json` and `render_compat.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- The built-in matrix is deliberately short; an empty Mobile list does not mean Mobile supports everything.
- Project-wide rendering settings (MSAA, TAA, upscaling) are not checked.
- Features enabled from code are not seen.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
