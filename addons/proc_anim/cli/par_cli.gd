## Procedural Animation Rigging Helper - headless CLI.
##   godot --headless --path . --script res://addons/proc_anim/cli/par_cli.gd -- [--out=<dir>] [--format=json,md] [--fail-on=errors,solver_error,missing_file]
extends SceneTree

const Core := preload("res://addons/proc_anim/core/par_solvers.gd")


func _init() -> void:
    var args := OS.get_cmdline_user_args()
    var op = Core.new()
    var cfg_path := "res://demo/anim/rig_config.json"
    for arg in args:
        if arg.begins_with("--config="):
            cfg_path = arg.trim_prefix("--config=")
    var result: Dictionary
    if not FileAccess.file_exists(cfg_path):
        result = {"summary": {"chains": 0, "solved": 0, "issues": 1}, "issues": [{"severity": "error", "kind": "missing_file", "path": cfg_path, "message": "Config not found: %s" % cfg_path, "fix": "Check the --config path."}]}
    else:
        var parsed = JSON.parse_string(FileAccess.get_file_as_string(cfg_path))
        result = op.run(parsed if typeof(parsed) == TYPE_DICTIONARY else {})
    _emit(op, result, args, "res://reports/proc_anim", ["errors","solver_error","missing_file"])


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
        _write(out_dir.path_join("proc_anim.json"), op.to_json(result))
    if formats.has("md"):
        _write(out_dir.path_join("proc_anim.md"), op.to_markdown(result))
    print("PAR summary: ", result.get("summary", {}))
    for i in result.get("issues", []):
        print("PAR [", i.get("severity", "info"), "] ", i.get("message", ""))
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
