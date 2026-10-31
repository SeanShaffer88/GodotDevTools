# Random Table Fairness Tester

Chi-square goodness-of-fit test of recorded outcome counts against a weighted table's intended odds. Enable the addon in Project Settings → Plugins and use **Test fairness** in the **RNG Fairness** dock.

Input:

```json
{"tables": {"gacha": {"weights": {"common": 80, "rare": 18, "legend": 2},
                      "observed": {"common": 860, "rare": 138, "legend": 2}}}}
```

`observed` counts come from your logs or a recorded session. For each table it computes Pearson's chi-square statistic with `k - 1` degrees of freedom and its p-value. Results below `--alpha` are reported as unlikely under the intended weights.

| Finding | Meaning |
|---|---|
| `unfair_distribution` | The p-value is below `--alpha`. |
| `low_sample` | An expected count is below 5, so the test is not reliable yet. |
| `unknown_outcome` | An observed outcome has no weight in the table. |

## Command line

```sh
godot --headless --path . --script res://addons/rng_fairness/cli/rft_cli.gd -- \
  --input=res://demo/balance/fairness.json --fail-on=unfair_distribution
```

Options: `--input=<path>` (default `res://demo/balance/fairness.json`), `--out=<dir>` (default `res://reports/rng_fairness`), `--alpha` (significance level (default 0.01)), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `rng_fairness.json` and `rng_fairness.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- A small p-value says the data and the weights disagree, not why; check the selection code and the logging.
- Testing many tables at alpha 0.01 will flag about 1 in 100 fair tables by chance.
- Pity timers and streak protection intentionally change odds; test raw rolls before those systems apply.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
