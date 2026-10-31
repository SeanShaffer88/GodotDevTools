# Large-project performance

Measured 2026-10-31 on Godot 4.3-stable headless (Linux; 2-core Intel Xeon @ 2.10 GHz cloud VM). Evidence label: **Partially verified**. The project is synthetic, and no Windows or desktop hardware was used.

## Project

`tests/bench/make_large_project.gd --scale=1` writes a deterministic project:
- 2,000 scripts
- 1,000 scenes with 21 nodes each, plus script and texture references
- 400 PNG textures
- 300 `.tres` resources
- 100 JSON data files

The 133 addons are copied in as well, giving 4,623 files in total (22 MB) and 800 imported assets. Import took 21 s.

## Method

`tests/bench/bench_cores.gd` loads every core whose `run()` defaults to scanning `res://` and times one `run("res://")` call. That covers 39 cores. `mutation_tester` and `suite_dispatcher` are excluded because they start child processes. Times include file reads. There is one run per tool, so expect noise of roughly ±10%.

```sh
godot --headless --path . --script res://tests/bench/make_large_project.gd -- --out=/abs/large
cp -r addons /abs/large/ && mkdir -p /abs/large/tests && cp -r tests/bench /abs/large/tests/
godot --headless --path /abs/large --import --quit-after 5
godot --headless --path /abs/large --script res://tests/bench/bench_cores.gd -- --out=/abs/bench.json
```

## Results

- All 39 scanners: 20.8 s in total. The median is 147 ms and the slowest is 4.4 s.
- Two hotspots were found and fixed in this pass. Both fixes produce the same findings as before: the full finding lists of old and new code were compared and are identical.
  - `cleanup_workbench`: 18,084 ms → 273 ms. It used to search the whole project text once per asset; it now builds a single reference set with one regex pass.
  - `privacy_audit`: 6,152 ms → 1,881 ms. Each pattern is now compiled once per scan instead of once per line.
- Before the fixes, the 39 scanners took 41.9 s in total.

| Addon | ms | Findings |
|---|---:|---:|
| a11y_options | 4350.6 | 7 |
| load_profiler | 2344.4 | 0 |
| unused_symbols | 2247.5 | 16002 |
| duplicate_code | 2191.2 | 5101 |
| privacy_audit | 1825.3 | 0 |
| script_complexity | 1120.7 | 1 |
| node_paths | 1117.0 | 108 |
| warning_baseline | 877.4 | 0 |
| offline_harness | 652.0 | 0 |
| scene_smoke | 608.7 | 0 |
| load_failure | 340.4 | 1 |
| lifecycle | 335.3 | 1 |
| scene_lint | 310.0 | 4000 |
| cleanup_workbench | 289.5 | 1339 |
| export_ranges | 284.8 | 0 |
| type_coverage | 269.5 | 0 |
| uid_integrity | 250.4 | 0 |
| light_cost | 194.2 | 0 |
| property_drift | 193.9 | 0 |
| physics_jitter | 147.3 | 0 |
| save_bloat | 100.5 | 100 |
| env_cost | 94.7 | 0 |
| shader_variants | 88.7 | 0 |
| theme_audit | 85.0 | 0 |
| overdraw | 77.2 | 0 |
| render_compat | 77.0 | 0 |
| lod_planner | 68.4 | 0 |
| anim_audit | 50.4 | 0 |
| hitbox_timeline | 48.7 | 0 |
| merge_conflicts | 38.6 | 0 |
| handheld_readiness | 38.4 | 1 |
| texture_filter | 11.7 | 0 |
| procgen_constraints | 9.3 | 0 |
| dialogue_vars | 8.8 | 0 |
| audio_levels | 8.7 | 0 |
| audio_import | 6.0 | 0 |
| art_handoff | 5.7 | 0 |
| mesh_stats | 4.9 | 0 |
| palette_check | 1.8 | 1 |

Findings are what each tool reports on synthetic content, for example `unused_symbols` flags the generated helper functions. They are not defects in the tools.
