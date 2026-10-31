# Shader Doctor

Static analysis of .gdshader files: redundant texture fetches, fetches in loops, branch density and dead uniforms, each with a concrete mobile-friendly rewrite.

Part of the **GodotDevTools** suite. Godot 4.3/4.5 (CI-verified), no third-party dependencies, no network use. MIT licensed.

## Install

Copy `addons/shader_doctor` into your project's `addons/` folder, then enable **Shader Doctor** under Project -> Project Settings -> Plugins. A dock appears on the right of the editor.

## In the editor

The dock runs the check against your project and lists every finding with severity, message and a concrete fix. Every control has a tooltip; the `?` button repeats this help inside the editor, offline.

## From the command line

```sh
godot --headless --path . --script res://addons/shader_doctor/cli/shd_cli.gd -- [options]
```

Run the CLI with no options once for a default report; it writes JSON + Markdown into `reports/shader_doctor/` and supports `--fail-on=...` exit-code-2 gates for CI. The full option list is in the header comment of the CLI script.

## How it works

The work lives in one core operation, `core/shd_analyzer.gd`, with no editor-only APIs, so the dock, the CLI and the tests all run exactly the same operation; the dock and CLI add no logic of their own. Godot compiles visual shaders to this same shading language, so hand-written and graph-generated code both get checked; the analyzer diagnoses and never rewrites your shader.
