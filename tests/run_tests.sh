#!/bin/sh
# Full gate for GodotDevTools. Usage: sh tests/run_tests.sh [godot-binary]
set -e
GODOT="${1:-godot}"
cd "$(dirname "$0")/.."

gate() { # gate <description> <script> [args...] - the CLI must exit 2
  desc="$1"
  shift
  echo "== CLI gate: $desc =="
  if "$GODOT" --headless --path . --script "$@"; then
    echo "FAIL: expected exit 2"; exit 1
  else
    [ $? -eq 2 ] || { echo "FAIL: expected exit 2"; exit 1; }
  fi
}

echo "== import (validates every demo scene/script parses in Godot) =="
"$GODOT" --headless --path . --import --quit-after 5
for t in vrt gstm ruip ahd dqd mns nlss a11y bed dbp smg cmv par aud mlh imx shd sgs lmx btd cor sdr wbx vfm tmr ctr thm pfg dcg sdm rg nc sub tel perf; do
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
gate "visual regression must exit 2 on the changed fixture pair" \
  res://addons/visual_regression/cli/vrt_cli.gd -- --baseline=res://demo/visual/baselines --current=res://demo/visual/current --fail-on=visual_diff
test -s visual_reports/menu__320x240.highlight.png
gate "asset health must exit 2 on duplicates" \
  res://addons/asset_health/cli/ahd_cli.gd -- --fail-on=duplicate
gate "dialogue debugger must exit 2 on missing target" \
  res://addons/dialogue_quest/cli/dqd_cli.gd -- --fail-on=missing_target
gate "accessibility must exit 2 on errors" \
  res://addons/accessibility/cli/a11y_cli.gd -- --fail-on=errors
gate "export doctor must exit 2 on the broken preset" \
  res://addons/export_doctor/cli/bed_cli.gd -- --fail-on=errors
echo "== CLI smoke: responsive UI + export doctor reports written =="
"$GODOT" --headless --path . --script res://addons/responsive_ui/cli/ruip_cli.gd
test -s reports/responsive_ui/responsive_ui.json
test -s reports/export_doctor/export_doctor.md
gate "batching profiler must exit 2 on the interleaved market fixture" \
  res://addons/batch_profiler/cli/dbp_cli.gd -- --fail-on=z_interleave
test -s reports/batch_profiler/batch_profiler.json
gate "schema migrator must exit 2 on the unmigratable save" \
  res://addons/schema_migrator/cli/smg_cli.gd -- --fail-on=unmigratable,missing_field
gate "collision matrix must exit 2 on the all-vs-all fixture" \
  res://addons/collision_matrix/cli/cmv_cli.gd -- --fail-on=all_vs_all
gate "procedural rig must exit 2 on the unreachable chain" \
  res://addons/proc_anim/cli/par_cli.gd -- --fail-on=solver_error
gate "audio sandbox must exit 2 on the ducking loop" \
  res://addons/audio_sandbox/cli/aud_cli.gd -- --fail-on=duck_loop,zone_stuck
gate "leak hunter must exit 2 on the orphan fixture" \
  res://addons/leak_hunter/cli/mlh_cli.gd -- --fail-on=orphan_risk,refcount_cycle
gate "input matrix must exit 2 on the colliding fixture" \
  res://addons/input_matrix/cli/imx_cli.gd -- --from=res://demo/input/actions.json --fail-on=binding_collision
echo "== CLI smoke: input matrix reads the live InputMap =="
"$GODOT" --headless --path . --script res://addons/input_matrix/cli/imx_cli.gd
gate "shader doctor must exit 2 on the redundant fetch fixture" \
  res://addons/shader_doctor/cli/shd_cli.gd -- --fail-on=redundant_fetch
gate "signal spy must exit 2 on the runaway session" \
  res://addons/signal_spy/cli/sgs_cli.gd -- --fail-on=runaway
gate "localization matrix must exit 2 on the missing translation" \
  res://addons/l10n_matrix/cli/lmx_cli.gd -- --fail-on=missing_translation
gate "behaviour debugger must exit 2 on the missing state" \
  res://addons/bt_debugger/cli/btd_cli.gd -- --fail-on=missing_state
gate "camera orchestrator must exit 2 on the unknown ease" \
  res://addons/camera_orch/cli/cor_cli.gd -- --fail-on=config_error
echo "== CLI smoke: seed replay verifies the clean log =="
"$GODOT" --headless --path . --script res://addons/seed_replay/cli/sdr_cli.gd
test -s reports/seed_replay/seed_replay.json
gate "seed replay must exit 2 on the tampered log" \
  res://addons/seed_replay/cli/sdr_cli.gd -- --log=res://demo/seeds/tampered_log.json --fail-on=mismatch
gate "whitebox must exit 2 on the off-grid fixture" \
  res://addons/whitebox/cli/wbx_cli.gd -- --fail-on=off_grid,steep_slope
gate "vfs mock must exit 2 on the case collision" \
  res://addons/vfs_mock/cli/vfm_cli.gd -- --fail-on=case_collision
gate "tilemap rules must exit 2 on the asymmetric rule" \
  res://addons/tilemap_rules/cli/tmr_cli.gd -- --fail-on=asymmetric_rule
echo "== CLI smoke: test runner plans the real suite =="
"$GODOT" --headless --path . --script res://addons/test_runner/cli/ctr_cli.gd
test -s reports/test_runner/test_runner.json
gate "test runner must exit 2 on the finish-less sample" \
  res://addons/test_runner/cli/ctr_cli.gd -- --dirs=res://demo/tests --fail-on=no_finish
echo "== CLI smoke: thermal simulation runs (estimates only) =="
"$GODOT" --headless --path . --script res://addons/thermal_sim/cli/thm_cli.gd
gate "thermal sim must exit 2 on the throttling workload" \
  res://addons/thermal_sim/cli/thm_cli.gd -- --fail-on=thermal_throttle
gate "prefab guard must exit 2 on the drifted instance" \
  res://addons/prefab_guard/cli/pfg_cli.gd -- --fail-on=drifted_property,default_drift
gate "doc generator must exit 2 on undocumented API" \
  res://addons/doc_gen/cli/dcg_cli.gd -- --fail-on=undocumented
test -s reports/doc_gen/api.md
test -s reports/doc_gen/api.html

gate "scene dependency map detects the unused fixture" \
  res://addons/scene_dependency/cli/sdm_cli.gd -- --dir=res://demo/dependencies --root=res://demo/dependencies/main.tscn --fail-on=unused_candidate
test -s reports/scene_dependency/scene_dependency.json
gate "release guard detects the placeholder fixture" \
  res://addons/release_guard/cli/rg_cli.gd -- --dir=res://demo/release_guard --fail-on=placeholder
test -s reports/release_guard/release_guard.json
gate "naming audit detects the inconsistent fixture" \
  res://addons/naming_conventions/cli/nc_cli.gd -- --dir=res://demo/naming --fail-on=file_name,directory_name
test -s reports/naming_conventions/naming_conventions.json
gate "subtitle auditor detects overlapping fixture cues" \
  res://addons/subtitle_audit/cli/sub_cli.gd -- --input=res://demo/subtitles/cues.json --fail-on=overlap
test -s reports/subtitle_audit/subtitle_audit.json
gate "telemetry validator detects the sensitive sample" \
  res://addons/telemetry_schema/cli/tel_cli.gd -- --schema=res://demo/telemetry/schema.json --samples=res://demo/telemetry/events.json --fail-on=sensitive_field
test -s reports/telemetry_schema/telemetry_schema.json
gate "performance gate detects the slower fixture" \
  res://addons/performance_gate/cli/perf_cli.gd -- --baseline=res://demo/performance/baseline.json --current=res://demo/performance/current.json --fail-on=regression
test -s reports/performance_gate/performance_gate.json
echo "ALL GATE CHECKS PASSED"
