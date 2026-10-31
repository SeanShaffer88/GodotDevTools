# GDScript Mutation Tester

Mutate comparison and boolean operators in one GDScript file and run its test against each mutant in an isolated copy; report mutants the test does not catch. Enable the addon in Project Settings → Plugins and use **Run mutation test** in the **Mutation Tester** dock.

Give it one script (`--target`) and a test (`--test`): a SceneTree script that exits 0 when it passes, like this repo's suites. It writes both, at their same `res://` paths, into a temporary project under `user://gdt_mutation`, checks that the test passes there unmodified, then for each mutant (one operator changed: `<` `<=` `>` `>=` `==` `!=` `and` `or` `true` `false`, outside strings and comments) runs the test in a separate headless Godot process. The summary gives the mutation score (killed / total).

| Finding | Meaning |
|---|---|
| `survived_mutant` | The test still passes with this operator changed: that behaviour is untested. |
| `baseline_failed` | The unmodified test fails in isolation (exit 1); it needs files beyond the target and test. |
| `timeout_mutant` | The mutant made the test hang past `--timeout` (counted as killed). |

## Command line

```sh
godot --headless --path . --script res://addons/mutation_tester/cli/gmt_cli.gd -- \
  --target=res://demo/ci/mutation/clamp_health.gd --test=res://demo/ci/mutation/test_clamp_health.gd --fail-on=survived_mutant
```

Options: `--target=<path>` (default `res://demo/ci/mutation/clamp_health.gd`), `--out=<dir>` (default `res://reports/mutation_tester`), `--test` (test script (a SceneTree script that exits 0 on pass)), `--max-mutants` (most mutants to run (default 30)), `--timeout` (seconds per run before the mutant counts as hanging (default 20)), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `mutation_tester.json` and `mutation_tester.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- Only the target and test are copied; tests that load other project files fail the isolation check - keep mutation targets small and self-contained.
- Some mutants are equivalent (e.g. `>` vs `>=` where both branches return the same value) and can never be killed.
- Each mutant starts a Godot process; expect about a second per mutant.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
