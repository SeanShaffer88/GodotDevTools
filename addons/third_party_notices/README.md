# Third-Party Notice Collector

Gather license files from addon and vendor folders into one notices report, flag folders without a license and copyleft licenses for review. Enable the addon in Project Settings → Plugins and use **Collect notices** in the **Third-Party Notices** dock.

Each immediate subfolder of `--dir` (default `res://addons`) is treated as one third-party package. The tool looks for `LICENSE`, `LICENCE`, `COPYING`, `NOTICE` or `COPYRIGHT` files (any extension, up to one folder deep), identifies common licenses by keywords (MIT, Apache-2.0, BSD, GPL, LGPL, AGPL, MPL-2.0, CC0, CC-BY, Zlib, Unlicense), and builds a combined notices text in the JSON report (`notices_text`) for your credits screen or `THIRD_PARTY_NOTICES` file.

| Finding | Meaning |
|---|---|
| `missing_license` | A package has no license file. |
| `copyleft_review` | A copyleft license (GPL, LGPL, AGPL, MPL) needs an obligations review. |
| `unknown_license` | A license file was found but not recognized. |

## Command line

```sh
godot --headless --path . --script res://addons/third_party_notices/cli/tpn_cli.gd -- \
  --dir=res://demo/shipping/vendor --fail-on=missing_license
```

Options: `--dir=<path>` (default `res://addons`), `--out=<dir>` (default `res://reports/third_party_notices`), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `third_party_notices.json` and `third_party_notices.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- Keyword identification is a hint, not a legal determination; read every license. Not legal advice.
- Licenses of fonts, art and audio outside the scanned folder are not found; point `--dir` at each vendor folder.
- Packages that keep their license only in a README are reported as missing.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
