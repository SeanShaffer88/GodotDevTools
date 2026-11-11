# Docker + standalone runner

## Docker (recommended for CI)

```sh
docker build -t godot-dev-tools .
docker run --rm -v "$PWD:/work" godot-dev-tools gate
docker run --rm -v "$PWD:/work" godot-dev-tools run naming_conventions --dir=res://demo/naming --fail-on=file_name
```

The image (`Dockerfile`) contains Ubuntu, Godot 4.3-stable, Xvfb/Mesa and the `gdt` wrapper. It does **not** bundle the addons or tests: the project mounted at `/work` must contain `addons/suite_dispatcher` and the requested addon; `gate` requires the repository's tests and fixtures. The examples above are intended to run from the repository root. The mount is writable and some tools execute project code, so use a trusted project or disposable copy. Containers run as root by default, so files they write to the mount can be root-owned; on a Linux host, use `--user "$(id -u):$(id -g)" -e HOME=/tmp` if you need reports owned by your user.

CI builds the image in `.github/workflows/docker.yml` and runs `python3 tests/docker_smoke.py --image godot-dev-tools` on a Linux Docker host. That smoke creates a disposable project, mounts it as `/work`, disables container networking, lists the installed tools and dispatches the Android export audit. It checks clean, selected-finding and invalid-input exit codes (0, 2 and 1), reports and omission of a fake secret; it does not validate Android devices. The [post-merge smoke](https://github.com/SeanShaffer88/GodotDevTools/actions/runs/43101484852) passed against the real image.

The workflow also runs `bash tests/docker_gate.sh godot-dev-tools` to exercise the full repository gate inside the image, using a disposable, writable mount, the host UID/GID, disabled container networking and a 600-second default timeout. The script archives committed `HEAD`, not uncommitted or untracked changes, and excludes `.git` and existing reports. See a CI run containing the “Run full gate in a mounted project” step for results; this new full-gate check has not yet run against a real container in this environment. `python3 tests/test_docker_smoke.py` and `python3 tests/test_docker_gate.py` test their respective harnesses with fake Docker commands, not real containers.

## Standalone (no Godot binary)

`tools/standalone/standalone.py` reimplements a documented subset in pure Python (stdlib only) for machines without Godot: currently the naming-conventions file/folder check. It exits 2 on any finding, 0 when clean and 1 on invalid input. The GDScript CLI returns 2 only for selected findings: pass `--fail-on=issues` for a comparable exit code. Both exclude Godot `.import` and `.uid` sidecar filenames as described in the [naming addon README](../addons/naming_conventions/README.md).

Everything else still needs Godot (scenes, imports, runtime). `tests/test_standalone.py` tests the Python subset and, when `GDT_GODOT_BIN` is set, compares the Godot CLI's findings and exit codes on an isolated fixture. Python and Godot use different regex engines, so arbitrary custom patterns may differ. See `tools/standalone/README.md` for limitations and commands.
