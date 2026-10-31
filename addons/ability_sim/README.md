# Gameplay Ability Simulator

Simulate an ability priority rotation with costs, cooldowns, cast times and resource regeneration; report casts, damage per second and starved time. Enable the addon in Project Settings → Plugins and use **Simulate rotation** in the **Ability Simulator** dock.

Input:

```json
{"duration": 60, "resources": {"mana": {"max": 100, "start": 100, "regen": 5}},
 "abilities": [{"id": "fireball", "cost": {"mana": 30}, "cooldown": 4, "cast_time": 1.0, "damage": 120}],
 "priority": ["fireball"]}
```

A fixed-step (`--step`, default 0.05 s) simulation: resources regenerate; when idle, the highest-priority ability that is off cooldown and affordable starts (cost paid and cooldown started at cast start; damage lands at cast end). The report lists casts and damage per ability, DPS, the share of time with nothing castable, and the share of time resources sat full.

| Finding | Meaning |
|---|---|
| `never_castable` | Cost above the resource maximum. |
| `cooldown_below_cast` | Cooldown shorter than the cast time. |
| `instant_spam` | Free, instant, no cooldown. |
| `never_used` | In the priority list but never cast. |
| `starved` | Nothing castable for more than `--max-idle` of the time. |

## Command line

```sh
godot --headless --path . --script res://addons/ability_sim/cli/gas_cli.gd -- \
  --input=res://demo/gameplay/abilities.json --fail-on=never_castable
```

Options: `--input=<path>` (default `res://demo/gameplay/abilities.json`), `--out=<dir>` (default `res://reports/ability_sim`), `--step` (simulation step in seconds (default 0.05)), `--max-idle` (share of time with nothing castable before flagging (default 0.3)), `--fail-on=<kinds>` (finding kinds above, `issues`, or `errors`). Writes `ability_sim.json` and `ability_sim.md`.

Exit codes: 2 when a `--fail-on` kind is found; 1 for unreadable input, an invalid argument or a report-write failure; otherwise 0.

## Limits

- A priority list is a simple player model; real players and AI weave, wait and react.
- Buffs, stacking, interrupts, crits and global cooldowns are not modelled; add them as explicit abilities or extend the core.
- Read-only: it never modifies project files.
- Headless tests on Godot 4.3 pass; hands-on editor verification of the dock is pending.
