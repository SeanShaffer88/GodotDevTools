# Build Size Attribution Explorer

Inspect the actual on-disk sizes of files in an **unpacked/staged build directory**, grouped by top-level folder and file extension. Enable the addon and enter a directory in the dock, or run:

```sh
godot --headless --path . --script res://addons/build_size/cli/bs_cli.gd -- \
  --dir=res://demo/build_size --max-file=1 --fail-on=file_budget
```

The scanner lists files largest first, sums their byte lengths, and optionally warns when a file exceeds `--max-file=<bytes>` or the total exceeds `--max-total=<bytes>`. Zero disables the respective budget. Limits are strict: exactly at the budget passes. Reports are written to `res://reports/build_size` by default (`--out` overrides). Put the report directory **outside** the scanned directory so later scans do not count earlier reports.

`--fail-on=file_budget,total_budget,skipped_link` or `--fail-on=issues` returns 2 for selected findings. Invalid budgets, unreadable directories/files or report-write failures return 1; errors take precedence. Otherwise the CLI returns 0. The default input is a small demo fixture.

Symbolic links and junctions encountered inside the scan are **not followed** and are reported as skipped; totals exclude them. Hidden files are included. A scan with errors or skipped links may be incomplete. The tool reports filesystem file lengths, not disk allocation. Staged folder totals may differ from the final compressed download size. The tool does not modify the build and needs no network.

## Inside Godot packs

Every `.pck` in the build is opened read-only, and so is a pack embedded at the end of an exported executable (`.exe`, `.x86_64`, `.arm64`, or a file with no extension). Its directory is attributed to the project paths it contains. The report's `archives` object lists, for each pack:
- the pack format, the Godot version that wrote it, and whether it was embedded;
- each packed file with its stored size;
- totals per top-level folder.

`--max-file` also applies to packed files, which are reported as `game.pck::res://art/hero.png`. Both pack formats are supported: format 2 (Godot 4.0-4.3) and format 3 (Godot 4.4+). Both are tested against packs written by Godot 4.3 and 4.5. Encrypted pack directories are reported as `pck_unreadable`. Sizes are the stored bytes inside the pack. Other archives (`.zip`, `.apk`) still appear as single files.
