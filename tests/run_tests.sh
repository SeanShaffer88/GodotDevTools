#!/bin/sh
# Full gate for GodotDevTools. Usage: sh tests/run_tests.sh [godot-binary]
set -e
GODOT="${1:-godot}"
cd "$(dirname "$0")/.."
echo "== import (validates every demo scene/script parses in Godot) =="
"$GODOT" --headless --path . --import --quit-after 5
for t in vrt gstm ruip ahd dqd mns nlss a11y bed; do
  echo "== test_$t =="
  "$GODOT" --headless --path . --script "res://tests/test_$t.gd"
done
echo "== CLI smoke: scene search =="
"$GODOT" --headless --path . --script res://addons/scene_search/cli/nlss_cli.gd -- --query="show scenes with a door interaction"
grep -q "door" reports/scene_search/scene_search.json
echo "== CLI smoke: time machine session verify =="
"$GODOT" --headless --path . --script res://addons/time_machine/cli/gstm_cli.gd -- --session=res://demo/time_machine/example_session.json
echo "== CLI smoke: network sim, clean channel exits 0 =="
"$GODOT" --headless --path . --script res://addons/network_sim/cli/mns_cli.gd -- --loss=0 --latency=3 --jitter=0
echo "== CLI gate: visual regression must exit 2 on the changed fixture pair =="
if "$GODOT" --headless --path . --script res://addons/visual_regression/cli/vrt_cli.gd -- --baseline=res://demo/visual/baselines --current=res://demo/visual/current --fail-on=visual_diff; then
  echo "FAIL: expected exit 2"; exit 1
else
  [ $? -eq 2 ] || { echo "FAIL: expected exit 2"; exit 1; }
fi
test -s visual_reports/menu__320x240.highlight.png
echo "== CLI gate: asset health must exit 2 on duplicates =="
if "$GODOT" --headless --path . --script res://addons/asset_health/cli/ahd_cli.gd -- --fail-on=duplicate; then
  echo "FAIL: expected exit 2"; exit 1
else
  [ $? -eq 2 ] || { echo "FAIL: expected exit 2"; exit 1; }
fi
echo "== CLI gate: dialogue debugger must exit 2 on missing target =="
if "$GODOT" --headless --path . --script res://addons/dialogue_quest/cli/dqd_cli.gd -- --fail-on=missing_target; then
  echo "FAIL: expected exit 2"; exit 1
else
  [ $? -eq 2 ] || { echo "FAIL: expected exit 2"; exit 1; }
fi
echo "== CLI gate: accessibility must exit 2 on errors =="
if "$GODOT" --headless --path . --script res://addons/accessibility/cli/a11y_cli.gd -- --fail-on=errors; then
  echo "FAIL: expected exit 2"; exit 1
else
  [ $? -eq 2 ] || { echo "FAIL: expected exit 2"; exit 1; }
fi
echo "== CLI gate: export doctor must exit 2 on the broken preset =="
if "$GODOT" --headless --path . --script res://addons/export_doctor/cli/bed_cli.gd -- --fail-on=errors; then
  echo "FAIL: expected exit 2"; exit 1
else
  [ $? -eq 2 ] || { echo "FAIL: expected exit 2"; exit 1; }
fi
echo "== CLI smoke: responsive UI + export doctor reports written =="
"$GODOT" --headless --path . --script res://addons/responsive_ui/cli/ruip_cli.gd
test -s reports/responsive_ui/responsive_ui.json
test -s reports/export_doctor/export_doctor.md
echo "ALL GATE CHECKS PASSED"
