#!/bin/sh
# Real editor session for every GodotDevTools dock (not headless).
# Usage: sh tests/editor/run_editor_session.sh <godot-binary> <scratch-dir>
# Copies the project to <scratch-dir>, installs the editor_verify harness
# plugin there, enables it, and runs the windowed editor under Xvfb
# (or on the current display if DISPLAY is set and xvfb-run is missing).
# Results: <scratch-dir>/reports/editor_verify/editor_verify.json + one PNG per dock.
set -e
GODOT="${1:?godot binary}"
WORK="${2:?new scratch dir}"
SRC="$(cd "$(dirname "$0")/../.." && pwd -P)"
# Never remove or overwrite an existing project or previous session.
PARENT="$(cd "$(dirname "$WORK")" && pwd -P)" || { echo "Scratch parent must exist: $WORK" >&2; exit 1; }
WORK="$PARENT/$(basename "$WORK")"
case "$WORK/" in "$SRC/"*) echo "Scratch directory must be outside the source repository." >&2; exit 1 ;; esac
if [ -e "$WORK" ] || [ -L "$WORK" ]; then
  echo "Scratch directory already exists; choose a new path: $WORK" >&2
  exit 1
fi
mkdir "$WORK"
( cd "$SRC" && tar cf - --exclude=./.git --exclude=./reports --exclude=./visual_reports . ) | ( cd "$WORK" && tar xf - )
cp -r "$SRC/tests/editor/editor_verify" "$WORK/addons/editor_verify"
# Enable the harness alongside the suite's own plugins.
sed -i 's#enabled=PackedStringArray(#enabled=PackedStringArray("res://addons/editor_verify/plugin.cfg", #' "$WORK/project.godot"
grep -q 'addons/editor_verify/plugin.cfg' "$WORK/project.godot"
"$GODOT" --headless --path "$WORK" --import --quit-after 5 >/dev/null 2>&1 || true
if command -v xvfb-run >/dev/null 2>&1; then
  timeout 1200 xvfb-run -a -s "-screen 0 1920x1080x24" "$GODOT" --editor --path "$WORK" --rendering-driver opengl3 --resolution 1920x1080
else
  timeout 1200 "$GODOT" --editor --path "$WORK" --rendering-driver opengl3 --resolution 1920x1080
fi
test -s "$WORK/reports/editor_verify/editor_verify.json"
echo "Editor session results: $WORK/reports/editor_verify/editor_verify.json"
# In addition to generic dock clicks, require each named interaction's
# concrete output (images/painted pixels, scene change, and Undo/Redo).
python3 - "$WORK/reports/editor_verify/editor_verify.json" <<'PY'
import json, os, sys
d = json.load(open(sys.argv[1]))
bad = [r["addon"] for r in d["results"] if not (r["dock_in_editor"] and r.get("visible") and r["clicked"] and r["output_changed"])]
required = {
    "macro_recorder": ["record_captured"],
    "visual_regression": ["capture_clicked", "capture_sizes", "capture_content"],
    "dialogue_quest": ["graph_layout", "graph_painted"],
    "responsive_ui": ["preview_clicked", "preview_sizes", "preview_content"],
    "whitebox": ["snap_clicked", "snap_applied", "snap_undo", "snap_redo"],
}
for row in d["results"]:
    fields = required.get(row["addon"], [])
    for field in fields:
        if not row.get(field):
            bad.append(f"{row['addon']} ({field})")
            print(f"Interaction evidence: {row['addon']}: {row}")
    if fields and os.environ.get("GITHUB_ACTIONS") == "true":
        evidence = {field: bool(row.get(field)) for field in fields}
        message = json.dumps(evidence).replace('%', '%25').replace('\r', '%0D').replace('\n', '%0A')
        print(f"::notice title=Editor interaction {row['addon']}::{message}")
print("Editor session: %d docks, %d failed%s (%s, %s)" % (len(d["results"]), len(bad), (": " + ", ".join(bad)) if bad else "", d["engine"], d["video_adapter"]))
sys.exit(1 if bad or len(d["results"]) == 0 else 0)
PY
