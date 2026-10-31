# Crafting and Inventory Graph Validator

Find unobtainable goals, inputs nothing produces, recipes that can only bootstrap themselves, and dead-end items. Enable the addon in Project Settings → Plugins and use **Validate crafting** in the **Crafting Graph** dock.

Input:

```json
{"base_items": ["wood", "ore"],
 "recipes": [{"id": "plank", "inputs": {"wood": 1}, "outputs": {"plank": 4}}],
 "goals": ["sword"]}
```

Base items are anything the player gets without crafting (gathering, shops, drops). Starting from them, every recipe whose inputs are all obtainable runs, adding its outputs, until nothing changes. The report lists obtainable items and how many recipes can ever run.

| Finding | Meaning |
|---|---|
| `unobtainable_goal` | A goal item is outside the reachable set. |
| `missing_input` | A recipe input has no producer and is not a base item. |
| `self_bootstrapping` | A recipe's missing input is produced only by that recipe. |
| `dead_end` | An obtainable crafted item is never used and is not a goal. |
| `duplicate_recipe` | Two recipes share an id. |

## Command line

```sh
godot --headless --path . --script res://addons/crafting_graph/cli/cgv_cli.gd -- \
  --input=res://demo/balance/crafting.json --fail-on=unobtainable_goal
```

Options: `--input=<path>` (default `res://demo/balance/crafting.json`), `--out=<dir>` (default `res://reports/crafting_graph`), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `crafting_graph.json` and `crafting_graph.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- Reachability only: quantities, costs, tool requirements, station unlocks and randomness are not modelled.
- Items consumed in other systems (quests, shops) look like dead ends; list them as goals to silence that.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
