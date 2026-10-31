# Shader Variant Budget Manager

Count distinct material feature combinations (each compiles its own shader) and preprocessor branches in custom shaders, against a variant budget. Enable the addon in Project Settings → Plugins and use **Count shader variants** in the **Shader Variants** dock.

It reads every `.tscn`, `.tres`, `.gdshader` and `.gdshaderinc` under the folder (hidden folders, `addons/` and report folders skipped). For `StandardMaterial3D` and `ORMMaterial3D` resources it builds a key from the class and every shader-affecting setting stored in the file (`*_enabled` flags, transparency, shading, blend, cull, depth draw, diffuse/specular modes, billboard and similar); materials differing only in colours or textures share a key. Each distinct key is roughly one generated shader to compile. In custom shaders it counts `#ifdef`/`#if` keywords.

| Finding | Meaning |
|---|---|
| `variant_budget` | Distinct material feature combinations exceed `--max-variants`. |
| `preprocessor_variants` | A shader has more than `--max-defines` preprocessor keywords. |
| `single_use_variant` | With the budget exceeded: a feature set only one material uses (a merge candidate). |

## Command line

```sh
godot --headless --path . --script res://addons/shader_variants/cli/svb_cli.gd -- \
  --dir=res://demo/perf_static --max-variants=3 --fail-on=variant_budget
```

Options: `--dir=<path>` (default `res://`), `--out=<dir>` (default `res://reports/shader_variants`), `--max-variants` (distinct material feature combinations allowed (default 32)), `--max-defines` (#ifdef/#if keywords per shader before it is flagged (default 2)), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `shader_variants.json` and `shader_variants.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- Estimate: the engine also varies shaders by mesh format, skinning, lighting and render pass, which this does not count.
- Materials created or changed from code are not seen; imported scene materials inside glTF/FBX are not read.
- Pair with a shader pre-compilation pass (Godot 4.x ubershader options) to address stutter.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
