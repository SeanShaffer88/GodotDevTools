# Docker + standalone runner

## Docker (recommended for CI)

```sh
docker build -t godot-dev-tools .
docker run --rm -v "$PWD:/work" godot-dev-tools gate
docker run --rm -v "$PWD:/work" godot-dev-tools run naming_conventions --dir=res://demo/naming --fail-on=file_name
```

The image (`Dockerfile`) is Ubuntu + Godot 4.3-stable + Xvfb/Mesa for the editor/live-game sessions. CI builds it in `.github/workflows/docker.yml`.

## Standalone (no Godot binary)

`tools/standalone/standalone.py` reimplements a documented subset in pure Python (stdlib only) for machines without Godot: currently the naming-conventions file/folder check. It exits 2 on any finding, 0 when clean and 1 on invalid input. The GDScript CLI returns 2 only for selected findings: pass `--fail-on=issues` for a comparable exit code. Both exclude Godot `.import` and `.uid` sidecar filenames as described in the [naming addon README](../addons/naming_conventions/README.md).

Everything else still needs Godot (scenes, imports, runtime). `tests/test_standalone.py` tests the Python subset and, when `GDT_GODOT_BIN` is set, compares the Godot CLI's findings and exit codes on an isolated fixture. Python and Godot use different regex engines, so arbitrary custom patterns may differ. See `tools/standalone/README.md` for limitations and commands.
