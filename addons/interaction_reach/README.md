# Interaction Reachability Checker

Check that every interactable's trigger area overlaps navmesh the player can walk to from the start point. Enable the addon in Project Settings → Plugins and use **Check interactions** in the **Interaction Reach** dock.

Interactables are `Area2D` nodes in a group, or with a name, containing `--pattern` (default `interact`). For each, the centre and eight edge points of its trigger shape (rectangle or circle collision shapes, translation only) are located on the baked navmesh (`--nav`); it is reachable when any of them lies in the same connected region as the player start (`--start=x,y`, or a node named/grouped `player`/`start`).

| Finding | Meaning |
|---|---|
| `unreachable_interactable` | No point of the trigger lies on navmesh reachable from the start. |
| `no_interactables` | No interactables found. |

## Command line

```sh
godot --headless --path . --script res://addons/interaction_reach/cli/irc_cli.gd -- \
  --scene=res://demo/gameplay/arena.tscn --nav=res://demo/gameplay/nav.tres --start=50,50 --fail-on=unreachable_interactable
```

Options: `--scene=<path>` (default `res://demo/gameplay/arena.tscn`), `--out=<dir>` (default `res://reports/interaction_reach`), `--nav` (baked NavigationPolygon .tres (required)), `--start` (player start as x,y (default: first node named or grouped 'player'/'start', else 0,0)), `--pattern` (group or name text marking interactables (default interact)), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `interaction_reach.json` and `interaction_reach.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- Reachability is navmesh connectivity; jumps, doors, keys and other gating are not modelled.
- Translation only; rotated or scaled triggers and instanced scenes are approximated or skipped.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
