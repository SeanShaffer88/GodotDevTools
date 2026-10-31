# Scene Dependency Map

A read-only static map of scene, script, shader, resource and asset references. Enable **Scene Dependency Map** in Project Settings → Plugins, then press **Scan dependencies** in the dock. Expand a file to inspect its direct outgoing references; entry points and autoload names are labeled. Findings appear above the map.

```sh
godot --headless --path . --script res://addons/scene_dependency/cli/sdm_cli.gd -- \
  --dir=res://demo/dependencies --root=res://demo/dependencies/main.tscn \
  --fail-on=missing_dependency,cycle
```

`--dir` defaults to `res://`; the scan excludes hidden directories and `addons`. Repeat `--root=res://...` to provide all entry points, or omit it to use the project's main scene and autoloads. `--out=<dir>` (default `res://reports/scene_dependency`) and `--format=json,md` select reports. Exit 2 when a selected `--fail-on` kind is present, otherwise 0. Kinds: `missing_dependency`, `cycle`, `long_chain` (8 nodes), `unused_candidate`, `unresolved_uid`, `no_roots`, plus `errors` and `issues`.

The scan recognizes quoted `res://` and resolvable `uid://` paths in text scenes, resources, GDScript, C# and shaders. Binary assets are nodes but not parsed for outgoing links. Literal references in comments may be included; dynamically constructed paths, class-name dependencies, editor-only references, and generated assets may be missed. Unreachable files are **candidates only**, never proof that deletion is safe. Supply all game entry points; if any configured root is outside the scanned inventory or unresolved, unused findings are suppressed. References to existing files outside the scan are not traversed. Long-chain warnings describe DFS traversal paths, not a complete enumeration of all possible paths. Never delete assets based on this report alone.

The tree view, core and CLI do not modify assets. Godot import is required for UID resolution. The visual dock still needs hands-on editor verification.
