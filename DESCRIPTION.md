# GodotDevTools

**Short (repo tagline, under 350 characters):**
133 independent, offline Godot 4 addons that catch performance, content, accessibility, testing and shipping problems before players do. Each addon has an editor dock, a headless CLI with JSON and Markdown reports, and a CI gate.

**Long:**
GodotDevTools is a suite of independent Godot 4 editor addons. Install only the ones you need. Every tool follows one contract: a pure core that reads your project, a thin editor dock with tooltips and offline help, and a headless CLI. The CLI writes JSON and Markdown reports and exits with code 2 when a `--fail-on` finding appears, so any tool can gate a pull request. The suite also includes a reusable GitHub Action.

The tools cover:
- Performance and rendering budgets
- Physics, navigation and gameplay balance
- Content and asset hygiene
- Localization and accessibility
- Testing: visual regression, mutation, property-based and flaky-test detection
- CI and release checks: export, shipping, privacy and save-format compatibility

Everything runs offline. There is no telemetry, the tools write only the reports you ask for, and deletions are only ever suggested. Godot 4.3 is the verified version. CI also passes on 4.5. Licensed under MIT.

**Topics:** godot, godot4, godot-addon, gdscript, game-development, devtools, static-analysis, ci, testing, accessibility, localization, performance
