# Deterministic Seed and Replay Runner

Verify run logs by replaying a hand-rolled deterministic PRNG and recomputing event hash chains - pinpoint the first divergence of a same-seed-different-outcome bug.

Part of the **GodotDevTools** suite. Godot 4.3/4.5 (CI-verified), no third-party dependencies, no network use. MIT licensed.

## Install

Copy `addons/seed_replay` into your project's `addons/` folder, then enable **Deterministic Seed and Replay Runner** under Project -> Project Settings -> Plugins. A dock appears on the right of the editor.

## In the editor

The dock runs the check against your project and lists every finding with severity, message and a concrete fix. Every control has a tooltip; the `?` button repeats this help inside the editor, offline.

## From the command line

```sh
godot --headless --path . --script res://addons/seed_replay/cli/sdr_cli.gd -- [options]
```

Run the CLI with no options once for a default report; it writes JSON + Markdown into `reports/seed_replay/` and supports `--fail-on=...` exit-code-2 gates for CI. The full option list is in the header comment of the CLI script.

## How it works

The work lives in one core operation, `core/sdr_runner.gd`, with no editor-only APIs, so the dock, the CLI and the tests all run exactly the same operation; the dock and CLI add no logic of their own. The optional in-game half lives in `runtime/sdr_rng.gd`: add it to a scene (or autoload it) and it uses the very same core. The PRNG (31-bit LCG) and the checksum (FNV-1a) are hand-rolled on purpose: any language can reproduce the sequence exactly, which is what makes replay verification honest.
