# Build Size Attribution Explorer

Inspect the actual on-disk sizes of files in an **unpacked/staged build directory**, grouped by top-level folder and file extension. Enable the addon and enter a directory in the dock, or run:

```sh
godot --headless --path . --script res://addons/build_size/cli/bs_cli.gd -- \
  --dir=res://demo/build_size --max-file=1 --fail-on=file_budget
```

The scanner lists files largest first, sums their byte lengths, and optionally warns when a file exceeds `--max-file=<bytes>` or the total exceeds `--max-total=<bytes>`. Zero disables the respective budget. Limits are strict: exactly at the budget passes. Reports are written to `res://reports/build_size` by default (`--out` overrides). Put the report directory **outside** the scanned directory so later scans do not count earlier reports.

`--fail-on=file_budget,total_budget,skipped_link` or `--fail-on=issues` returns 2 for selected findings. Invalid budgets, unreadable directories/files or report-write failures return 1; errors take precedence. Otherwise the CLI returns 0. The default input is a small demo fixture.

Symbolic links and junctions encountered inside the scan are **not followed** and are reported as skipped; totals exclude them. Hidden files are included. A scan with errors or skipped links may be incomplete. The tool reports filesystem file lengths, not disk allocation. It does **not** unpack or attribute `.pck`, `.zip`, `.apk`, executables or other archives to individual source assets; those appear as single files. Staged folder totals may differ from final compressed download size. It does not modify the build, and requires no network. Godot execution and a hands-on editor session remain to be verified.
