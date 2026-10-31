## Multi-Platform Input Matrix and Rebinding Suite - headless CLI.
##   godot --headless --path . --script res://addons/input_matrix/cli/imx_cli.gd -- [--out=<dir>] [--format=json,md] [--fail-on=errors,binding_collision,no_gamepad,missing_file]
extends SceneTree

const Core := preload("res://addons/input_matrix/core/imx_matrix.gd")


func _init() -> void:
    var args := OS.get_cmdline_user_args()
    var op = Core.new()
    var actions: Dictionary = {}
    var from := ""
    for arg in args:
        if arg.begins_with("--from="):
            from = arg.trim_prefix("--from=")
    var result: Dictionary
    if from != "":
        if not FileAccess.file_exists(from):
            result = {"summary": {"actions": 0, "devices": 4, "collisions": 0, "coverage_gaps": 0, "issues": 1}, "matrix": {}, "remap_menu": [], "issues": [{"severity": "error", "kind": "missing_file", "path": from, "message": "Actions file not found: %s" % from, "fix": "Check the --from path."}]}
        else:
            var parsed = JSON.parse_string(FileAccess.get_file_as_string(from))
            result = op.run(parsed if typeof(parsed) == TYPE_DICTIONARY else {})
    else:
        for action in InputMap.get_actions():
            if str(action).begins_with("ui_") or str(action).begins_with("spatial_editor"):
                continue
            var events: Array = []
            for ev in InputMap.action_get_events(str(action)):
                events.append(op.classify_event(ev))
            actions[str(action)] = events
        result = op.run(actions)
    _emit(op, result, args, "res://reports/input_matrix", ["errors","binding_collision","no_gamepad","missing_file"])


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
        _write(out_dir.path_join("input_matrix.json"), op.to_json(result))
    if formats.has("md"):
        _write(out_dir.path_join("input_matrix.md"), op.to_markdown(result))
    print("IMX summary: ", result.get("summary", {}))
    for i in result.get("issues", []):
        print("IMX [", i.get("severity", "info"), "] ", i.get("message", ""))
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
