# False positives log

Confirmed examples from dogfooding (`docs/DOGFOOD.md`), not an exhaustive review. A finding can accurately match a configured rule while still being a project-specific policy choice; do not label all findings as defects.

| Tool | Project / file | Why it is wrong as an independent naming finding | Status |
|---|---|---|---|
| Naming conventions | [Brackeys first game](https://github.com/Brackeys/first-game-in-godot/tree/388257461dbd07b1e5020270c72fca48b30c493d), `assets/fonts/PixelOperator8-Bold.ttf.import` | The [pre-fix CI run](https://github.com/SeanShaffer88/GodotDevTools/actions/runs/42957927997) flagged Godot import metadata as a second asset. Its `[deps] source_file` points to `PixelOperator8-Bold.ttf`, which is separately checked. | Fixed by skipping compound `.import` filenames. The [post-fix Godot run](https://github.com/SeanShaffer88/GodotDevTools/actions/runs/42960094940) reports only the two source fonts. |
| Naming conventions | [Godot platformer starter](https://github.com/deanblackborough/godot-platformer/tree/5ce74ba7e3ffcd2e9339ebbca763b0a32bab1cf5), `Core/Combat/HitBox.gd.uid` | The pinned file contains a Godot UID and belongs to the separately checked `HitBox.gd`; the pre-fix standalone scan flags `HitBox.gd` as its basename. The Godot audit used the same basename rule. | Fixed by skipping compound `.uid` filenames; the post-fix Godot run still reports the source `HitBox.gd`. Regression coverage added. |

The exclusion is suffix-based, not content-validated; deliberately authored files with these compound suffixes will also be skipped. Orphaned sidecars remain excluded. Single-extension files and sidecar-named directories are still audited.

No false-positive rate is published yet. A meaningful rate for a tool and project/version requires adjudicating **every finding in the same report**, then dividing confirmed false positives by the total findings in that report. The examples above and the CI counts alone do not meet that standard. Repeat the review after scanner changes, and record suppressions separately from fixes.
