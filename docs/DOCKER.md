# Docker + standalone runner

## Docker (recommended for CI)

```sh
docker build -t godot-dev-tools .
docker run --rm -v "$PWD:/work" godot-dev-tools gate
docker run --rm -v "$PWD:/work" godot-dev-tools run naming_conventions --dir=res://demo/naming --fail-on=file_name
```

The image (`Dockerfile`) is Ubuntu + Godot 4.3-stable + Xvfb/Mesa for the editor/live-game sessions. CI builds it in `.github/workflows/docker.yml`.

## Standalone (no Godot binary)

`tools/standalone/standalone.py` reimplements a documented subset in pure Python (stdlib only) for machines without Godot: currently the naming-conventions file/folder check. It exits 2 on findings, 0 when clean — same contract as the GDScript CLI. Everything else still needs Godot (scenes, imports, runtime). The subset will grow only where the logic is pure text and the Python port is covered by a parity test against the GDScript CLI on the demo fixture.
