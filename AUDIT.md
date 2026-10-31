# AUDIT.md - GodotDevTools security, privacy and quality audit

Audit date: 2026-10-31. Scope: all 133 addons under `addons/`, the CLIs, runtime nodes, CI workflows and the reusable GitHub Action. Method: repository-wide search for every API that can reach the network, start processes, delete files, evaluate code or deserialize objects. Each finding was then read in context and, where behaviour was uncertain, probed on Godot 4.3-stable headless.

Evidence labels follow PROJECT_RULES.md: **Verified** (run or tested here), **Partially verified** (code read and covered by tests, but not exercised end to end), and **Unverified**.

## Summary

| Area | Result |
|---|---|
| Network access | No tool contacts the network on its own. The single opt-in runtime wrapper is listed below. |
| Process launch | Four call sites. Each one launches the running Godot binary or `chmod`, with fixed arguments and no shell. |
| File deletion | One call site, which removes only a hook the tool itself wrote. |
| Code evaluation | Three `Expression` call sites that evaluate the user's own formula files with no base instance. |
| Object deserialization | Two `str_to_var` call sites. Hardened in this audit (finding F1). |
| Telemetry, accounts, cloud | None. |
| Writes | Reports and artifacts the user asked for, user:// scratch copies, and the opt-in git hook. |

## Findings

### F1 - `str_to_var` built live objects from data files (fixed)

- Where: `addons/macro_recorder/core/eam_macro.gd` (`_value`) and `addons/settings_validator/core/ssv_validator.gd` (`flatten`).
- Issue: on Godot 4.3, `str_to_var('Object(Node,"name":"x")')` returns a live `Node`. This is **Verified** by a headless probe. A crafted macro or settings file could therefore instantiate engine classes when it was loaded.
- Fix: the macro recorder now refuses any `Object(...)` value and returns null. The settings validator keeps such values as plain text and compares them as strings, so `project.godot` input-map entries still diff correctly.
- Tests: `test_eam.gd` checks "object values in a macro are refused". `test_ssv.gd` checks "object values are compared as text, never built". Both **Verified**.

### F2 - `Expression` evaluation of formula files (accepted)

- Where: `xp_curve/core/xpc_planner.gd`, `damage_sandbox/core/dfs_sandbox.gd` and `property_tests/core/pbt_tester.gd`.
- Behaviour: formulas come from the user's own JSON files, are parsed with an explicit list of input names, and run with no base instance. The headless probe showed that `OS.get_name()` and `Engine.get_version_info()` both fail to execute in this mode (**Verified** on 4.3). Combination counts are capped (`--max-combinations`).
- Residual risk: treat formula files as code from your own project. Expression behaviour on other Godot versions is **Unverified**.

### F3 - Process launches (accepted)

- `suite_dispatcher/core/gdt_registry.gd` runs `OS.execute(OS.get_executable_path(), argv)`. The tool name is checked against `/` and `..`, and the CLI path is resolved under `res://addons/<tool>/cli`.
- `test_runner/cli/ctr_cli.gd` runs the Godot binary with `--check-only` on test scripts listed in its own scan.
- `mutation_tester/core/gmt_mutator.gd` runs `OS.create_process` on a scratch copy of the project. It enforces a per-run timeout and calls `OS.kill` when the timeout is hit.
- `precommit/core/pch_hook.gd` runs `chmod +x` on the hook it just wrote. This is non-Windows only, and only when `--install` is set.
- None of these call sites invokes a shell or passes user text as a command. **Partially verified**: the dispatcher, test runner and mutator are exercised by the gate. The chmod path runs only on install, which the gate covers in a scratch git folder.

### F4 - File deletion (accepted)

- `precommit/core/pch_hook.gd --uninstall` removes `.git/hooks/pre-commit` only when the file carries the tool's marker. A foreign hook is reported (`foreign_hook`) and left untouched. **Verified** by `test_pch.gd`.
- No other tool deletes files. Tools that report unused or orphaned assets only suggest deletions.

### F5 - Network-capable runtime node (accepted, opt-in)

- `offline_harness/runtime/ocn_http.gd` is a drop-in replacement for `HTTPRequest` that simulates offline, timeout and fixture responses. A request reaches the network only when no fixture or fault rule matches. In that case it falls back to a real `HTTPRequest` and applies a timeout. It exists only in games that add it, never in the editor tools.
- `privacy_audit` and `offline_harness` mention network classes only in order to scan for them.

### F6 - CI supply chain (note)

- Workflows use `actions/checkout@v7`, `actions/cache@v6` and `actions/upload-artifact@v7` by major tag, not by commit SHA. For stronger supply-chain guarantees, pin them to SHAs. This is left as is to match the repo's existing convention.

## Quality audit

- Every one of the 133 addons has a core, an editor dock (`ui/`), a headless CLI (`cli/`), a README and a test suite. This was checked by script on 2026-10-31.
- Gate: `sh tests/run_tests.sh` runs every suite, CLI smoke test and exit-code-2 gate. The result for this branch is recorded in the PR.
- The limits are the same as those in QUALITY.md. Editor docks and runtime nodes are **Partially verified** until a hands-on editor session. Large-project performance and Godot versions other than 4.3 and 4.5 are **Unverified**. Estimator tools produce comparative numbers, not measurements.

## How to repeat this audit

```sh
for p in HTTPRequest HTTPClient StreamPeerTCP PacketPeerUDP WebSocket OS.execute OS.create_process OS.shell_open Expression.new remove_absolute OS.move_to_trash str_to_var bytes_to_var; do
  printf '%s: ' "$p"; grep -rlF "$p" addons --include=*.gd | tr '\n' ' '; echo
done
```

Any new hit needs an entry above before merging.
