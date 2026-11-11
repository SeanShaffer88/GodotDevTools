#!/bin/sh
# Real editor session for every GodotDevTools dock (not headless).
# Usage: sh tests/editor/run_editor_session.sh <godot-binary> <scratch-dir>
# Copies the project to <scratch-dir>, installs the editor_verify harness
# plugin there, enables it, and runs the windowed editor under Xvfb
# (or on the current display if DISPLAY is set and xvfb-run is missing).
# Results: <scratch-dir>/reports/editor_verify/editor_verify.json + one PNG per dock.
set -e
GODOT="${1:?godot binary}"
WORK="${2:?scratch dir}"
SRC="$(cd "$(dirname "$0")/../.." && pwd)"
rm -rf "$WORK"
mkdir -p "$WORK"
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
# Pass/fail: every dock must be found in the editor, clicked, and show output;
# the macro recorder must also capture an Inspector edit.
python3 - "$WORK/reports/editor_verify/editor_verify.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
bad = [r["addon"] for r in d["results"] if not (r["dock_in_editor"] and r.get("visible") and r["clicked"] and r["output_changed"])]
bad += [r["addon"] + " (record)" for r in d["results"] if r["addon"] == "macro_recorder" and not r.get("record_captured")]
print("Editor session: %d docks, %d failed%s (%s, %s)" % (len(d["results"]), len(bad), (": " + ", ".join(bad)) if bad else "", d["engine"], d["video_adapter"]))
sys.exit(1 if bad or len(d["results"]) == 0 else 0)
PY
