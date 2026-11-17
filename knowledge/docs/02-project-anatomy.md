# 02 — Project anatomy and version control

From the official Project organization and Version control systems
docs.

## What a project is made of

| Piece | What it is |
|---|---|
| `project.godot` | INI-style project file at the root: app name, main scene (`run/main_scene`), autoloads, input map, project settings. Committed. |
| Scenes | `.tscn` (text — readable, mergeable) or `.scn` (binary). Resources likewise: `.tres` text, `.res` binary. |
| Scripts | `.gd` (GDScript) / `.cs` (C#), kept beside the scenes they attach to. Paths are `res://`-rooted. |
| `addons/` | Top-level folder for editor plugins (each a subfolder with `plugin.cfg`, enabled under Project Settings → Plugins) and third-party resources generally — including Asset Store downloads and Android plugins. |
| `export_presets.cfg` | Project root; every export preset, including Android package name, version, architectures, permissions, keystore fields, and Gradle options. |
| `.godot/` | Editor cache (imported assets, UID cache, shader cache). Fully regenerable; never committed. |
| `android/` | Appears only after installing the Gradle build template; the generated Android project lives under `res://android/build`. |

Godot uses the filesystem as-is — no asset database, no metadata
files beyond `.import` sidecars next to imported assets.
Conventions from the style guide: group assets close to the scenes
that use them, snake_case file and folder names (C# scripts
excepted), and a `.gdignore` file stops the importer processing a
folder.

## Version control (Godot 4.1+)

The official ignore list is exactly two entries:

```
.godot/
*.translation
```

Everything else is source and is committed — `project.godot`,
scenes, scripts, `.import` sidecars, and `export_presets.cfg`.
That last one surprises people coming from old tutorials: Godot
3.x and 4.0 could store sensitive credentials in
`export_presets.cfg`; **4.1 and later do not**, which is why the
guidance flipped. (Keystore *passwords* still never go in the repo
— CI passes them by environment variable, docs/03.)

The Project Manager can generate the `.gitignore` / `.gitattributes`
for you (Project → Version Control → Generate Version Control
Metadata), enforcing LF endings; Windows Git users without the
generated metadata should set `core.autocrlf` to `input`. The docs
also provide a Git LFS starter for large binaries (models, images,
audio, fonts, and binary resources like `*.scn` / `*.res`).
