# Environment Feature Cost Matrix

List the post-processing and GI features each Environment enables, with relative cost tiers and renderer support. Enable the addon in Project Settings → Plugins and use **Build environment matrix** in the **Environment Cost** dock.

It reads `Environment` sub-resources inside scenes and standalone `Environment` `.tres` files under the folder (hidden folders, `addons/` and report folders skipped) and lists which features are enabled. Each feature has a relative cost tier used only to compare setups:

| Feature | Tier |
|---|---|
| SDFGI, screen-space reflections, screen-space indirect lighting, volumetric fog | high |
| Screen-space ambient occlusion | medium |
| Glow, depth fog, colour adjustments | low |

When the project renderer (or `--renderer`) is `gl_compatibility`, features that renderer does not implement are flagged.

| Finding | Meaning |
|---|---|
| `expensive_feature` | A feature above `--max-cost` is enabled. |
| `unsupported_in_renderer` | A feature the Compatibility renderer does not implement is enabled. |

## Command line

```sh
godot --headless --path . --script res://addons/env_cost/cli/ecm_cli.gd -- \
  --dir=res://demo/rendering --renderer=forward_plus --fail-on=expensive_feature
```

Options: `--dir=<path>` (default `res://`), `--out=<dir>` (default `res://reports/env_cost`), `--max-cost` (highest tier allowed: low, medium or high (default medium)), `--renderer` (forward_plus, mobile or gl_compatibility (default: read from project.godot)), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `env_cost.json` and `env_cost.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- Tiers are a relative ranking, not GPU timings; real cost depends on resolution, quality settings and hardware. Profile on target devices.
- Quality settings (project-wide SSAO/SSR quality, half resolution) are not read.
- Mobile-renderer support is not modelled; check Godot's renderer comparison for your version.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
