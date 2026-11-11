# Standalone runner

Pure-Python, standard-library subset for machines without Godot. Currently only the naming-conventions **file/folder** check is implemented; there are no symbol checks or JSON/Markdown reports. See `docs/DOCKER.md`.

```sh
python3 tools/standalone/standalone.py naming --dir=demo/naming
python3 tests/test_standalone.py
GDT_GODOT_BIN=/path/to/godot python3 tests/test_standalone.py
```

The standalone command exits 2 on any finding, 0 when clean, and 1 for an invalid pattern, missing scan directory or bad arguments. For comparable Godot CLI exit codes, use `--fail-on=issues`; the Godot CLI otherwise permits unselected findings. Both skip compound `.import`/`.uid` sidecar filenames and check their sources, single-extension files and sidecar-named directories. The sidecar rule is a suffix heuristic; see `addons/naming_conventions/README.md`.

The regression tests cover the demo and generated sidecar fixtures. With `GDT_GODOT_BIN` set, they also run the Godot CLI on an isolated fixture and compare finding kinds, paths, counts and exit codes for the default and a shared custom pattern. CI runs this comparison. Python's `re` and Godot's PCRE2 have different syntax and features, so parity is not guaranteed for arbitrary custom expressions, error handling or scanners outside this subset.
