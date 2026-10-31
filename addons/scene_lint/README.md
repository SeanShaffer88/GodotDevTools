# Scene Lint Rule Engine

Check scenes against user-defined JSON rules: required child types, forbidden or required properties, and node-name patterns. Enable the addon in Project Settings → Plugins and use **Lint scenes** in the **Scene Lint** dock.

It parses every `.tscn` under the folder (hidden folders, `addons/` and report folders skipped) into nodes with their type, name, parent and stored properties, then applies rules. Built-in rules require a collision shape child under 2D/3D physics bodies and areas. Pass `--rules=<file>` to replace them with your own:

```json
[
  {"id": "body-needs-shape", "match_type": "CharacterBody2D", "require_child_type": ["CollisionShape2D", "CollisionPolygon2D"]},
  {"id": "pascal-case-nodes", "match_type": "*", "name_pattern": "^[A-Z][A-Za-z0-9]*$"},
  {"id": "no-font-overrides", "match_type": "Label", "forbid_property": "theme_override_font_sizes/font_size"},
  {"id": "centered", "match_type": "Label", "require_property": "horizontal_alignment", "equals": "1"}
]
```

Each rule needs an `id`, a `match_type` (a type, a list of types, or `"*"`) and exactly one check; optional `severity` and `fix` customize findings.

| Finding | Meaning |
|---|---|
| `rule_violation` | A node breaks a rule; the message starts with the rule id. |
| `bad_rules` | The rules file is missing or malformed (exit 1). |

## Command line

```sh
godot --headless --path . --script res://addons/scene_lint/cli/slr_cli.gd -- \
  --dir=res://demo/scene_lint --fail-on=rule_violation
```

Options: `--dir=<path>` (default `res://`), `--out=<dir>` (default `res://reports/scene_lint`), `--rules` (JSON rules file; replaces the built-in rules), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `scene_lint.json` and `scene_lint.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- Properties are compared as the text the scene stores; defaults are not stored, so `require_property` fails on default values.
- Instanced child scenes have no type in the parent's text and match only `"*"`; their insides are linted in their own file.
- Built-in rules do not see shapes added from code.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
