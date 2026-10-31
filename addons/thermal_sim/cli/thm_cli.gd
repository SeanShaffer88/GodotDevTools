## Mobile Thermal and Battery Drain Emulation Dock - headless CLI.
##   godot --headless --path . --script res://addons/thermal_sim/cli/thm_cli.gd -- [--out=<dir>] [--format=json,md] [--fail-on=errors,config_error,thermal_throttle,battery_drain_high,frame_budget_exceeded,missing_file]
extends SceneTree

const Core := preload("res://addons/thermal_sim/core/thm_model.gd")


func _init() -> void:
    var args := OS.get_cmdline_user_args()
    var op = Core.new()
    var workload_path := "res://demo/thermal/workload.json"
    for arg in args:
        if arg.begins_with("--workload="):
            workload_path = arg.trim_prefix("--workload=")
    var result: Dictionary
    if not FileAccess.file_exists(workload_path):
        result = {"summary": {"profile": "", "samples": 0, "peak_temp_c": 0.0, "throttle_at_s": -1, "avg_watts": 0.0, "battery_hours": 0.0, "budget_broken": 0, "issues": 1}, "timeline": [], "issues": [{"severity": "error", "kind": "missing_file", "path": workload_path, "message": "Workload not found: %s" % workload_path, "fix": "Check the --workload path."}]}
    else:
        var parsed = JSON.parse_string(FileAccess.get_file_as_string(workload_path))
        var cfg: Dictionary = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
        result = op.run(cfg.get("timeline", []), str(cfg.get("profile", "mid_android_estimate")))
    _emit(op, result, args, "res://reports/thermal_sim", ["errors","config_error","thermal_throttle","battery_drain_high","frame_budget_exceeded","missing_file"])


func _write(path: String, content: String) -> bool:
    var f := FileAccess.open(path, FileAccess.WRITE)
    if f == null:
        printerr("Could not write ", path)
        return false
    f.store_string(content)
    f.close()
    return true


func _emit(op, result: Dictionary, args: Array, default_out: String, fail_kinds: Array) -> void:
    var out_dir := default_out
    var formats: Array[String] = ["json", "md"]
    for arg in args:
        if arg.begins_with("--out="):
            out_dir = arg.trim_prefix("--out=")
        elif arg.begins_with("--format="):
            formats.assign(arg.trim_prefix("--format=").split(","))
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
    if formats.has("json"):
        _write(out_dir.path_join("thermal_sim.json"), op.to_json(result))
    if formats.has("md"):
        _write(out_dir.path_join("thermal_sim.md"), op.to_markdown(result))
    print("THM summary: ", result.get("summary", {}))
    for i in result.get("issues", []):
        print("THM [", i.get("severity", "info"), "] ", i.get("message", ""))
    var failed := false
    var fail_on: Array[String] = []
    for arg in args:
        if arg.begins_with("--fail-on="):
            fail_on.assign(arg.trim_prefix("--fail-on=").split(","))
    for k in fail_kinds:
        if fail_on.has(k):
            for i in result.get("issues", []):
                if i.get("kind", "") == k:
                    failed = true
    if fail_on.has("errors"):
        for i in result.get("issues", []):
            if i.get("severity", "") == "error":
                failed = true
    if fail_on.has("issues") and not (result.get("issues", []) as Array).is_empty():
        failed = true
    quit(2 if failed else 0)
