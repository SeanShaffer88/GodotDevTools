# Examples

The canonical worked examples are upstream's:

- **godotengine/godot-demo-projects** — the official demo
  collection; the Android-relevant ones show the export and input
  patterns in real projects.
- **Google's Godot guides** on developer.android.com ("Install
  Godot and configure projects for Android", "Export Godot
  projects to Android") — the Play-side view of the pipeline in
  docs/03. Caution: their C# sections are Godot 3-era (Mono) and
  stale for Godot 4; the export flow itself is current.

And this repo's own:

- **The GodotDevTools addons** (the `addons/` folder here) —
  141 dev-tool addons; their docks, CLIs, and CI gates are worked
  examples of editor tooling, headless checks, and shipping
  discipline for Godot 4 projects.

Read examples against the docs, not instead of them: an example
proves a pattern ran once, on one version; the docs carry the
version-pinned rules.
