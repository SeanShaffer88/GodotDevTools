# Settings File Validator

Validate player settings files (ConfigFile .cfg or JSON) against a schema of types, ranges, allowed values and defaults. Enable the addon in Project Settings → Plugins and use **Validate settings** in the **Settings Validator** dock.

Schema (default `schema.json` inside the settings folder):

```json
{"fields": {"audio/master_volume": {"type": "float", "min": 0.0, "max": 1.0, "default": 0.8},
            "video/resolution": {"type": "string", "enum": ["1280x720", "1920x1080"], "default": "1920x1080"}}}
```

Every other `.cfg` (Godot ConfigFile text, values parsed with `str_to_var`) or `.json` file in the folder is a sample settings file; JSON objects one level deep become `section/key`. Collect samples from testers and old versions to make sure your loader's assumptions hold.

| Finding | Meaning |
|---|---|
| `unknown_key` | A key the schema does not define (old or misspelled). |
| `wrong_type` | A value of the wrong type. |
| `out_of_range` | A number outside min/max. |
| `invalid_enum` | A value not in the allowed list. |
| `missing_key` | A schema key is absent (default applies). |
| `bad_schema` | Schema missing or malformed (exit 1). |

## Command line

```sh
godot --headless --path . --script res://addons/settings_validator/cli/ssv_cli.gd -- \
  --dir=res://demo/shipping/settings --fail-on=out_of_range
```

Options: `--dir=<path>` (default `res://demo/shipping/settings`), `--out=<dir>` (default `res://reports/settings_validator`), `--schema` (schema JSON (default: schema.json in the settings folder)), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `settings_validator.json` and `settings_validator.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- Validates sample files; it does not test your loader. Pair findings with clamping and defaults in code.
- Only one level of JSON nesting is flattened.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
