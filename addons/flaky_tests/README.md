# Flaky Test Detector

Read a history of test runs (JUnit XML or JSON) and find tests that both pass and fail on the same commit, flip often, or always fail. Enable the addon in Project Settings → Plugins and use **Find flaky tests** in the **Flaky Tests** dock.

Input is a folder of JUnit XML files (one per run, ordered by file name) or a JSON history:

```json
{"runs": [{"commit": "abc123", "results": {"test_net": "pass"}}, {"commit": "abc123", "results": {"test_net": "fail"}}]}
```

In JUnit files a testcase with a `failure` or `error` child failed, `skipped` is ignored, and a `<property name="commit" value="...">` identifies the commit. For each test it reports runs, failures and the share of consecutive runs whose outcome flipped.

| Finding | Meaning |
|---|---|
| `flaky_same_commit` | The test passed and failed on the same commit. |
| `high_flip_rate` | No commit data proves it, but the outcome flips in at least `--flip-rate` of consecutive runs. |
| `always_failing` | The test failed in every run (broken, not flaky). |

## Command line

```sh
godot --headless --path . --script res://addons/flaky_tests/cli/flk_cli.gd -- \
  --input=res://demo/ci/junit --fail-on=flaky_same_commit
```

Options: `--input=<path>` (default `res://demo/ci/junit`), `--out=<dir>` (default `res://reports/flaky_tests`), `--flip-rate` (share of consecutive runs that flip pass/fail before a test is flagged (default 0.3)), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `flaky_tests.json` and `flaky_tests.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- Without commit identifiers only the weaker flip-rate signal is available; add the commit as a JUnit property in CI.
- Tests renamed between runs count as different tests.
- It does not re-run anything; collect history from CI artifacts.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
