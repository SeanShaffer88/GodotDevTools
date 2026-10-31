# Node Property Drift Monitor

Learn each node type's usual stored property values across scenes and flag the outliers that drift from the team convention, or check against a baseline file. Enable the addon in Project Settings → Plugins and use **Find property drift** in the **Property Drift** dock.

Without `--baseline`, it learns conventions: for each node type and stored property (layout, transform, text, script and resource properties ignored), if at least `--min-nodes` nodes store it and one value holds at least `--majority` of them, every other value is an outlier. With `--baseline=<json>` (`{"Label": {"horizontal_alignment": "1"}}`), every node of a listed type is compared, and values not stored count as `(default)`.

| Finding | Meaning |
|---|---|
| `property_outlier` | A stored value differs from the learned convention. |
| `baseline_mismatch` | A value differs from the baseline. |
| `bad_baseline` | Baseline missing or malformed (exit 1). |

## Command line

```sh
godot --headless --path . --script res://addons/property_drift/cli/npd_cli.gd -- \
  --dir=res://demo/workflow/drift --fail-on=property_outlier
```

Options: `--dir=<path>` (default `res://`), `--out=<dir>` (default `res://reports/property_drift`), `--baseline` (JSON {Type: {property: value}} to enforce instead of learning conventions), `--min-nodes` (nodes storing a property before conventions are learned (default 5)), `--majority` (share the dominant value needs to count as a convention (default 0.7)), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `property_drift.json` and `property_drift.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- Learning sees stored values only; nodes using the default are not counted in learned mode.
- A deliberate exception looks like drift; record exceptions with the Finding Suppression Baseline.
- Theme-driven styling is invisible here; see the Theme Resource Auditor.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
