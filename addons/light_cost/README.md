# 3D Light and Shadow Cost Estimator

Count 3D lights and shadow-casting lights per scene, following instanced scenes, against budgets. Enable the addon in Project Settings → Plugins and use **Estimate light cost** in the **Light Cost** dock.

It reads every `.tscn` under the folder (hidden folders, `addons/` and report folders skipped) and counts `OmniLight3D`, `SpotLight3D` and `DirectionalLight3D` nodes per scene, following instanced scenes, plus how many have `shadow_enabled = true`. The renderer comes from `rendering/renderer/rendering_method` in `project.godot` unless `--renderer` is given.

| Finding | Meaning |
|---|---|
| `shadow_budget` | Shadow-casting omni/spot lights exceed `--max-shadowed`. |
| `light_budget` | Omni/spot lights exceed `--max-lights`. |
| `multiple_directional_shadows` | More than one directional light casts shadows. |
| `renderer_light_limit` | Mobile or Compatibility renderer and more omni/spot lights in the scene than the default per-object limit (8). |

## Command line

```sh
godot --headless --path . --script res://addons/light_cost/cli/lsc_cli.gd -- \
  --dir=res://demo/rendering --fail-on=shadow_budget
```

Options: `--dir=<path>` (default `res://`), `--out=<dir>` (default `res://reports/light_cost`), `--max-shadowed` (shadow-casting omni/spot lights per scene (default 4)), `--max-lights` (omni/spot lights per scene (default 32)), `--renderer` (forward_plus, mobile or gl_compatibility (default: read from project.godot)), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `light_cost.json` and `light_cost.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- Counts are per scene, not per visible frame: culling, visibility ranges and lights toggled at runtime are not modelled.
- The per-object limit applies to lights overlapping one mesh; a scene count above it is a prompt to check, not proof.
- Baked lights (bake mode Static) still count; they cost less at runtime.
- Lights created from code are not seen.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
