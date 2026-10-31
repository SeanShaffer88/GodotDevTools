# CI and Headless Test Runner

Discover and classify test files, plan the exact headless commands, emit JUnit XML and triage --check-only output into errors versus warnings.

Part of the **GodotDevTools** suite. Godot 4.3/4.5 (CI-verified), no third-party dependencies, no network use. MIT licensed.

## Install

Copy `addons/test_runner` into your project's `addons/` folder, then enable **CI and Headless Test Runner** under Project -> Project Settings -> Plugins. A dock appears on the right of the editor.

## In the editor

The dock runs the check against your project and lists every finding with severity, message and a concrete fix. Every control has a tooltip; the `?` button repeats this help inside the editor, offline.

## From the command line

```sh
godot --headless --path . --script res://addons/test_runner/cli/ctr_cli.gd -- [options]
```

Run the CLI with no options once for a default report; it writes JSON + Markdown into `reports/test_runner/` and supports `--fail-on=...` exit-code-2 gates for CI. The full option list is in the header comment of the CLI script.

## How it works

The work lives in one core operation, `core/ctr_runner.gd`, with no editor-only APIs, so the dock, the CLI and the tests all run exactly the same operation; the dock and CLI add no logic of their own. This repo's own suite lives in tests/run_tests.sh; the runner is for the games that import it. GUT is detected from file text, never depended on.
