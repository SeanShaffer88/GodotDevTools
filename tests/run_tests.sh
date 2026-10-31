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
for t in vrt gstm ruip ahd dqd mns nlss a11y bed dbp smg cmv par aud mlh imx shd sgs lmx btd cor sdr wbx vfm tmr ctr thm pfg dcg sdm rg nc sub tel perf flag bs cert coverage priority pbi opa npb usf tcm scx dup era alg uid psd slr lts dca dfs xpc cgv ach wsb rft sba dvl fgc ala aia atp tfc msr lsc ecm pcc tra flk gst lgr lbg sdt isf gwb sst mbh gmt sav apr vcc tpn rln cdc pde ssv aoc hrc rsv srf jux hdb rdf; do
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
# Review queue records decisions separately and does not update baselines.
"$GODOT" --headless --path . --script res://addons/visual_regression/cli/vrt_cli.gd -- --baseline=res://demo/visual/baselines --current=res://demo/visual/current --review-queue
test -s visual_reports/review_queue.json
"$GODOT" --headless --path . --script res://addons/visual_regression/cli/vrt_review_cli.gd -- --queue=res://visual_reports/review_queue.json --out=res://visual_reports/review_decided.json --name=menu__320x240.png --decision=approved --reviewer=ci
grep -q '"reviewer": "ci"' visual_reports/review_decided.json
gate "asset health must exit 2 on duplicates" \
  res://addons/asset_health/cli/ahd_cli.gd -- --fail-on=duplicate
gate "asset health flags texture budget and preset mismatch" \
  res://addons/asset_health/cli/ahd_cli.gd -- --preset=res://demo/import_preset/rules.json --texture-budget=1 --fail-on=texture_budget,preset_mismatch
grep -q 'texture_estimate_bytes' reports/asset_health/asset_health.json
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
echo "== scene dependency change and rename preview =="
"$GODOT" --headless --path . --script res://addons/scene_dependency/cli/sdm_cli.gd -- --dir=res://demo/dependencies --root=res://demo/dependencies/main.tscn --impact=res://demo/dependencies/material.tres --rename-to=res://demo/dependencies/new_material.tres
grep -q 'direct_references' reports/scene_dependency/scene_dependency.json
gate "scene dependency rejects identical rename destination" \
  res://addons/scene_dependency/cli/sdm_cli.gd -- --dir=res://demo/dependencies --root=res://demo/dependencies/main.tscn --impact=res://demo/dependencies/material.tres --rename-to=res://demo/dependencies/material.tres --fail-on=same_destination
gate "release guard detects the placeholder fixture" \
  res://addons/release_guard/cli/rg_cli.gd -- --dir=res://demo/release_guard --fail-on=placeholder
test -s reports/release_guard/release_guard.json
gate "naming audit detects the inconsistent fixture" \
  res://addons/naming_conventions/cli/nc_cli.gd -- --dir=res://demo/naming --fail-on=file_name,directory_name
test -s reports/naming_conventions/naming_conventions.json
gate "naming audit detects bad symbols" \
  res://addons/naming_conventions/cli/nc_cli.gd -- --dir=res://demo/naming_symbols --symbols --fail-on=node_name,signal_name,group_name
gate "subtitle auditor detects overlapping fixture cues" \
  res://addons/subtitle_audit/cli/sub_cli.gd -- --input=res://demo/subtitles/cues.json --fail-on=overlap
test -s reports/subtitle_audit/subtitle_audit.json
gate "subtitle auditor detects SRT overlap" \
  res://addons/subtitle_audit/cli/sub_cli.gd -- --input=res://demo/subtitles/overlap.srt --fail-on=overlap
gate "subtitle auditor detects WebVTT overlap" \
  res://addons/subtitle_audit/cli/sub_cli.gd -- --input=res://demo/subtitles/overlap.vtt --fail-on=overlap
gate "telemetry validator detects the sensitive sample" \
  res://addons/telemetry_schema/cli/tel_cli.gd -- --schema=res://demo/telemetry/schema.json --samples=res://demo/telemetry/events.json --fail-on=sensitive_field
test -s reports/telemetry_schema/telemetry_schema.json
gate "performance gate detects the slower fixture" \
  res://addons/performance_gate/cli/perf_cli.gd -- --baseline=res://demo/performance/baseline.json --current=res://demo/performance/current.json --fail-on=regression
test -s reports/performance_gate/performance_gate.json
gate "flag simulator detects unknown prerequisites" \
  res://addons/flag_simulator/cli/flag_cli.gd -- --config=res://demo/flags/flags.json --fail-on=errors
test -s reports/flag_simulator/flag_simulator.json
"$GODOT" --headless --path . --script res://addons/flag_simulator/cli/flag_cli.gd -- --config=res://demo/flags/clean.json --unavailable
gate "build size explorer detects an over-budget file" \
  res://addons/build_size/cli/bs_cli.gd -- --dir=res://demo/build_size --max-file=1 --fail-on=file_budget
test -s reports/build_size/build_size.json
gate "checklist reports failed requirement" \
  res://addons/cert_check/cli/cert_cli.gd -- --fail-on=failed_check
test -s reports/cert_check/cert_check.json
gate "state coverage reports unvisited transition" \
  res://addons/state_coverage/cli/coverage_cli.gd -- --fail-on=uncovered_transition
test -s reports/state_coverage/state_coverage.json
gate "state coverage detects discontinuous trace" \
  res://addons/state_coverage/cli/coverage_cli.gd -- --first=res://demo/state_coverage/model.json --second=res://demo/state_coverage/discontinuous_trace.json --check-continuity --fail-on=trace_discontinuity
gate "test prioritizer reports unmapped path" \
  res://addons/test_priority/cli/priority_cli.gd -- --fail-on=unmapped_path
test -s reports/test_priority/test_priority.json
echo "== test priority dependency graph smoke =="
"$GODOT" --headless --path . --script res://addons/test_priority/cli/priority_cli.gd -- --first=res://demo/test_priority/graph_mapping.json --second=res://demo/test_priority/graph_changes.json --graph=res://demo/test_priority/graph.json --fail-on=unmapped_path
grep -q 'test_sdm.gd' reports/test_priority/test_priority.json
gate "particle budget detects the over-budget campfire" \
  res://addons/particle_budget/cli/pbi_cli.gd -- --dir=res://demo/particles --max-scene=3000 --fail-on=scene_budget
test -s reports/particle_budget/particle_budget.json
gate "pool advisor detects the per-frame bullet" \
  res://addons/pool_advisor/cli/opa_cli.gd -- --dir=res://demo/pooling --counts=res://demo/pooling/counts.json --fail-on=pool_candidate,high_spawn_rate
grep -q 'bullet.tscn' reports/pool_advisor/pool_advisor.json
gate "node path detector finds the missing muzzle" \
  res://addons/node_paths/cli/npb_cli.gd -- --dir=res://demo/code_health --fail-on=broken_path
test -s reports/node_paths/node_paths.json
gate "unused symbol finder reports the never-fired signal" \
  res://addons/unused_symbols/cli/usf_cli.gd -- --dir=res://demo/code_health --fail-on=never_emitted
test -s reports/unused_symbols/unused_symbols.json
gate "type coverage gate fails below 90 percent" \
  res://addons/type_coverage/cli/tcm_cli.gd -- --dir=res://demo/code_health --min-percent=90 --fail-on=project_below_threshold
test -s reports/type_coverage/type_coverage.json
gate "complexity reporter flags the nested decision function" \
  res://addons/script_complexity/cli/scx_cli.gd -- --dir=res://demo/code_health --fail-on=complex_function,deep_nesting
test -s reports/script_complexity/script_complexity.json
gate "duplicate detector finds the copied scoring loop" \
  res://addons/duplicate_code/cli/dup_cli.gd -- --dir=res://demo/code_health --fail-on=duplicate_block
test -s reports/duplicate_code/duplicate_code.json
gate "export range auditor flags the overfilled health" \
  res://addons/export_ranges/cli/era_cli.gd -- --dir=res://demo/export_ranges --fail-on=out_of_range
test -s reports/export_ranges/export_ranges.json
gate "autoload graph flags the early Events reference" \
  res://addons/autoload_graph/cli/alg_cli.gd -- --project=res://demo/autoloads/autoloads.godot --fail-on=init_order
gate "uid checker flags the stale reference" \
  res://addons/uid_integrity/cli/uid_cli.gd -- --dir=res://demo/uids --fail-on=uid_mismatch
gate "settings drift reports the changed fps cap" \
  res://addons/settings_drift/cli/psd_cli.gd -- --project=res://demo/settings_drift/current.cfg --baseline=res://demo/settings_drift/baseline.cfg --fail-on=setting_changed
gate "scene lint flags the hero without a collision shape" \
  res://addons/scene_lint/cli/slr_cli.gd -- --dir=res://demo/scene_lint --fail-on=rule_violation
gate "loot simulator flags the dragon blade drought" \
  res://addons/loot_sim/cli/lts_cli.gd -- --input=res://demo/balance/loot.json --fail-on=drought_risk
gate "difficulty analyzer flags the level 4 spike" \
  res://addons/difficulty_curve/cli/dca_cli.gd -- --input=res://demo/balance/difficulty.json --fail-on=difficulty_spike
gate "damage sandbox flags negative damage" \
  res://addons/damage_sandbox/cli/dfs_cli.gd -- --input=res://demo/balance/damage.json --fail-on=negative_result
gate "xp planner flags the level 5 wall" \
  res://addons/xp_curve/cli/xpc_cli.gd -- --input=res://demo/balance/xp.json --fail-on=level_wall
gate "crafting validator flags the unobtainable amulet" \
  res://addons/crafting_graph/cli/cgv_cli.gd -- --input=res://demo/balance/crafting.json --fail-on=unobtainable_goal
gate "achievement checker flags the unreachable tycoon" \
  res://addons/achievements/cli/ach_cli.gd -- --input=res://demo/balance/achievements.json --fail-on=unreachable_threshold
gate "wave planner flags the wave 2 crowd" \
  res://addons/wave_budget/cli/wsb_cli.gd -- --input=res://demo/balance/waves.json --fail-on=alive_budget
gate "fairness tester flags the rigged gacha" \
  res://addons/rng_fairness/cli/rft_cli.gd -- --input=res://demo/balance/fairness.json --fail-on=unfair_distribution
gate "save auditor flags the growing event log" \
  res://addons/save_bloat/cli/sba_cli.gd -- --dir=res://demo/balance/saves --fail-on=key_growth
gate "dialogue variable lint flags variables nothing sets" \
  res://addons/dialogue_vars/cli/dvl_cli.gd -- --dir=res://demo/dialogue --fail-on=read_never_set
gate "glyph checker flags locales the ASCII font cannot draw" \
  res://addons/font_glyphs/cli/fgc_cli.gd -- --font=res://demo/assets_audit/ascii_only.ttf --strings=res://demo/assets_audit --fail-on=missing_glyphs
gate "audio auditor flags the clipped boom" \
  res://addons/audio_levels/cli/ala_cli.gd -- --dir=res://demo/assets_audit --fail-on=clipping
gate "audio import auditor flags the non-looping theme" \
  res://addons/audio_import/cli/aia_cli.gd -- --dir=res://demo/assets_audit --fail-on=music_not_looping
gate "atlas planner reports the oversize background" \
  res://addons/atlas_planner/cli/atp_cli.gd -- --input=res://demo/assets_audit/atlas.json --fail-on=sprite_too_big
gate "texture filter checker flags mipmapped pixel art" \
  res://addons/texture_filter/cli/tfc_cli.gd -- --dir=res://demo/assets_audit --fail-on=pixel_mipmaps
gate "mesh stats flags the over-budget terrain" \
  res://addons/mesh_stats/cli/msr_cli.gd -- --dir=res://demo/rendering --max-triangles=5000 --fail-on=triangle_budget
gate "light estimator flags the shadowed street lamps" \
  res://addons/light_cost/cli/lsc_cli.gd -- --dir=res://demo/rendering --fail-on=shadow_budget
gate "environment matrix flags high-cost features" \
  res://addons/env_cost/cli/ecm_cli.gd -- --dir=res://demo/rendering --renderer=forward_plus --fail-on=expensive_feature
gate "palette checker flags the off-palette accent" \
  res://addons/palette_check/cli/pcc_cli.gd -- --dir=res://demo/rendering --palette=res://demo/rendering/palette.json --fail-on=off_palette
gate "theme auditor flags font-size sprawl" \
  res://addons/theme_audit/cli/tra_cli.gd -- --dir=res://demo/rendering --fail-on=font_size_sprawl
gate "flaky detector finds the network test" \
  res://addons/flaky_tests/cli/flk_cli.gd -- --input=res://demo/ci/junit --fail-on=flaky_same_commit
gate "golden tester flags the changed score" \
  res://addons/golden_snapshot/cli/gst_cli.gd -- --current=res://demo/ci/golden/actual --golden=res://demo/ci/golden/expected --fail-on=changed_value
gate "log grouper reports error groups" \
  res://addons/log_grouper/cli/lgr_cli.gd -- --log=res://demo/ci/logs/run.log --fail-on=error_group
gate "log budget catches new errors" \
  res://addons/log_budget/cli/lbg_cli.gd -- --log=res://demo/ci/logs/run.log --baseline=res://demo/ci/logs/baseline.json --fail-on=error_budget
gate "trace diff finds the divergence" \
  res://addons/trace_diff/cli/sdt_cli.gd -- --first=res://demo/ci/traces/run_a.json --second=res://demo/ci/traces/run_b.json --fail-on=divergence
gate "input fuzzer reports the unbound dash" \
  res://addons/input_fuzzer/cli/isf_cli.gd -- --project=res://demo/ci/input_actions.godot --fail-on=unbound_action
grep -q '"sequences"' reports/input_fuzzer/input_fuzzer.json
gate "warning baseline catches the new unused variable" \
  res://addons/warning_baseline/cli/gwb_cli.gd -- --dir=res://demo/ci/warnings --baseline=res://demo/ci/warnings/baseline.json --fail-on=warning_increase
gate "scene smoke test flags the legacy node type" \
  res://addons/scene_smoke/cli/sst_cli.gd -- --dir=res://demo/ci/smoke --fail-on=unknown_type
echo "== bench harness output feeds the performance gate =="
"$GODOT" --headless --path . --script res://addons/bench_harness/cli/mbh_cli.gd -- --script=res://demo/ci/bench/bench_math.gd --iterations=5 --warmup=1
grep -q '"bench_math.bench_sum_array"' reports/bench_harness/bench_harness.json
gate "mutation tester finds surviving boundary mutants" \
  res://addons/mutation_tester/cli/gmt_cli.gd -- --target=res://demo/ci/mutation/clamp_health.gd --test=res://demo/ci/mutation/test_clamp_health.gd --fail-on=survived_mutant
gate "store validator flags the undersized icon" \
  res://addons/store_assets/cli/sav_cli.gd -- --profile=res://demo/shipping/store/profile.json --fail-on=wrong_size
gate "permission reviewer flags camera and location" \
  res://addons/android_permissions/cli/apr_cli.gd -- --presets=res://demo/shipping/android_presets.cfg --fail-on=sensitive_permission
gate "version checker flags the stale Windows product version" \
  res://addons/version_consistency/cli/vcc_cli.gd -- --project=res://demo/shipping/version_project.godot --presets=res://demo/shipping/android_presets.cfg --fail-on=version_mismatch
gate "notice collector flags the unlicensed package" \
  res://addons/third_party_notices/cli/tpn_cli.gd -- --dir=res://demo/shipping/vendor --fail-on=missing_license
gate "release notes flag the breaking change" \
  res://addons/release_notes/cli/rln_cli.gd -- --commits=res://demo/shipping/commits.txt --fail-on=breaking_change
gate "content checklist flags the unanswered question" \
  res://addons/content_descriptor/cli/cdc_cli.gd -- --input=res://demo/shipping/descriptors.json --today=2026-10-31 --fail-on=unanswered
gate "patch estimator flags the over-budget patch" \
  res://addons/patch_delta/cli/pde_cli.gd -- --old=res://demo/shipping/builds/v1 --new=res://demo/shipping/builds/v2 --max-delta=10000 --fail-on=delta_budget
gate "settings validator flags the out-of-range volume" \
  res://addons/settings_validator/cli/ssv_cli.gd -- --dir=res://demo/shipping/settings --fail-on=out_of_range
gate "options coverage flags missing colour-blind support" \
  res://addons/a11y_options/cli/aoc_cli.gd -- --dir=res://demo/shipping --fail-on=option_not_found
gate "handheld checklist flags the mouse-only action" \
  res://addons/handheld_readiness/cli/hrc_cli.gd -- --dir=res://demo/shipping/handheld --project=res://demo/shipping/handheld/project_handheld.godot --fail-on=no_gamepad_binding
gate "report schema flags the malformed report" \
  res://addons/report_schema/cli/rsv_cli.gd -- --reports=res://demo/suite/after --fail-on=schema_violation
test -s reports/report_schema/report.schema.json
gate "SARIF exporter notes the skipped report" \
  res://addons/sarif_export/cli/srf_cli.gd -- --reports=res://demo/suite/after --fail-on=skipped_report
test -s reports/sarif_export/gdt.sarif
gate "JUnit exporter notes the skipped report" \
  res://addons/junit_export/cli/jux_cli.gd -- --reports=res://demo/suite/after --fail-on=skipped_report
test -s reports/junit_export/gdt-junit.xml
gate "dashboard notes the skipped report" \
  res://addons/html_dashboard/cli/hdb_cli.gd -- --reports=res://demo/suite/after --fail-on=skipped_report
test -s reports/html_dashboard/dashboard.html
gate "report diff gates on new findings" \
  res://addons/report_diff/cli/rdf_cli.gd -- --before=res://demo/suite/before --after=res://demo/suite/after --fail-on=new_finding
echo "ALL GATE CHECKS PASSED"
