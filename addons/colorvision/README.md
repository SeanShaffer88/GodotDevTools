# Color-Vision and Contrast Previewer

Simulate protanopia, deuteranopia and tritanopia for a palette and flag colour pairs that become hard to tell apart. Enable the addon in Project Settings → Plugins and use **Simulate colour vision** in the **Color Vision** dock.

Input: `{"colors": {"health": "#2ca02c", "danger": "#d62728"}, "min_delta_e": 12}`. Every colour is simulated for full-severity protanopia, deuteranopia and tritanopia (Machado, Oliveira and Fernandes 2009 matrices applied in linear sRGB), and every pair is compared by CIE76 delta E in each view. The report's `preview` lists the simulated hex colours, so a dock or design tool can show swatches side by side.

| Finding | Meaning |
|---|---|
| `indistinct_under_cvd` | A pair falls below `min_delta_e` under a simulation. |
| `indistinct_normal` | A pair is already too close with typical colour vision. |

## Command line

```sh
godot --headless --path . --script res://addons/colorvision/cli/cvp_cli.gd -- \
  --input=res://demo/glyphs/palette_cvd.json --fail-on=indistinct_under_cvd
```

Options: `--input=<path>` (default `res://demo/glyphs/palette_cvd.json`), `--out=<dir>` (default `res://reports/colorvision`), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `colorvision.json` and `colorvision.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- Full-severity simulations; anomalous trichromacy (partial deficiency, the most common case) sits between normal and these results.
- Palette colours only; textures, gradients and lighting are not simulated. Pair with the Accessibility Checker and playtests.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
