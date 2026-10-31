# Store Asset Validator

Check store icons, headers and screenshots against a profile you write: required files, exact or allowed sizes, and screenshot counts. Enable the addon in Project Settings → Plugins and use **Validate store assets** in the **Store Assets** dock.

You write the profile from each store's current documentation:

```json
{"assets": [
  {"id": "icon", "path": "res://store/icon.png", "width": 512, "height": 512},
  {"id": "screenshots", "folder": "res://store/screens", "sizes": [[1920, 1080], [1280, 720]], "min_count": 3, "max_count": 10}]}
```

An asset is either one file (`path` with `width`/`height` or a `sizes` list) or a folder of PNG/JPEG images with allowed `sizes` and a count range. Sizes come from the PNG IHDR or JPEG SOF header.

| Finding | Meaning |
|---|---|
| `missing_asset` | A single-file asset does not exist. |
| `wrong_size` | An image's size is not allowed, or unreadable. |
| `count_out_of_range` | A folder has too few or too many images. |
| `bad_profile` | The profile is missing or malformed (exit 1). |

## Command line

```sh
godot --headless --path . --script res://addons/store_assets/cli/sav_cli.gd -- \
  --profile=res://demo/shipping/store/profile.json --fail-on=wrong_size
```

Options: `--profile=<path>` (default `res://demo/shipping/store/profile.json`), `--out=<dir>` (default `res://reports/store_assets`), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `store_assets.json` and `store_assets.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- Store requirements change and differ by store and region; the tool only knows your profile and makes no compliance claim.
- File size limits, colour profiles, alpha channels and content rules are not checked.
- PNG and JPEG only (WebP, GIF and video trailers are not read).
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
