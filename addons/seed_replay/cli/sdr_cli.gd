## Deterministic Seed and Replay Runner - headless CLI.
##   godot --headless --path . --script res://addons/seed_replay/cli/sdr_cli.gd -- [--out=<dir>] [--format=json,md] [--fail-on=errors,mismatch,chain_break]
extends SceneTree

const Core := preload("res://addons/seed_replay/core/sdr_runner.gd")


func _init() -> void:
    var args := OS.get_cmdline_user_args()
    var op = Core.new()
    var log_path := "res://demo/seeds/run_log.json"
    for arg in args:
        if arg.begins_with("--log="):
            log_path = arg.trim_prefix("--log=")
    var loaded := op.load_run_log(log_path)
    var result: Dictionary = op.verify(loaded["log"])
    result["issues"] = (loaded["errors"] as Array) + (result.get("issues", []) as Array)
    result["summary"]["issues"] = (result["issues"] as Array).size()
    _emit(op, result, args, "res://reports/seed_replay", ["errors","mismatch","chain_break"])


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
        _write(out_dir.path_join("seed_replay.json"), op.to_json(result))
    if formats.has("md"):
        _write(out_dir.path_join("seed_replay.md"), op.to_markdown(result))
    print("SDR summary: ", result.get("summary", {}))
    for i in result.get("issues", []):
        print("SDR [", i.get("severity", "info"), "] ", i.get("message", ""))
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
