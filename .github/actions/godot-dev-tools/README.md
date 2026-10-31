# GodotDevTools CI action

A composite GitHub Action that downloads a Godot release, imports your project and runs GodotDevTools CLIs through the Suite CLI Dispatcher. The job fails if any command exits non-zero (a `--fail-on` finding exits 2, invalid input exits 1).

Requirements: the GodotDevTools addons you use, including `addons/suite_dispatcher`, are in your project; a Linux runner.

```yaml
jobs:
  godot-checks:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - uses: SeanShaffer88/GodotDevTools/.github/actions/godot-dev-tools@main
        with:
          godot-version: 4.3-stable
          commands: |
            run node_paths --fail-on=broken_path
            run scene_lint --fail-on=rule_violation
            run export_doctor --fail-on=errors
      - uses: actions/upload-artifact@v7
        if: always()
        with:
          name: godot-dev-tools-reports
          path: reports/
```

Inputs:

| Input | Default | Meaning |
|---|---|---|
| `godot-version` | `4.3-stable` | Godot release tag downloaded from GitHub releases. |
| `project-path` | `.` | Folder containing `project.godot`. |
| `commands` | (required) | One dispatcher command per line: `run <tool> [options]`, `list` or `all`. |

Reports land in `<project>/reports/<tool>/`. Pair with the SARIF Exporter (`run sarif_export`) and your code-scanning upload step, or the JUnit Exporter for test views.

Limits: Linux runners only (it downloads the Linux build). Pin a commit SHA instead of `@main` for reproducible builds. This repository's own CI exercises the action on every push and pull request.
