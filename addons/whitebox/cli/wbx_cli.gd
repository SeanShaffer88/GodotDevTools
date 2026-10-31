## Level Whiteboxing and Snapping Suite - headless CLI.
##   godot --headless --path . --script res://addons/whitebox/cli/wbx_cli.gd -- [--out=<dir>] [--format=json,md] [--fail-on=errors,off_grid,steep_slope,missing_file]
extends SceneTree

const Core := preload("res://addons/whitebox/core/wbx_snap.gd")


func _init() -> void:
    var args := OS.get_cmdline_user_args()
    var op = Core.new()
    var scene_path := "res://demo/whitebox/blockout.tscn"
    var grid_path := "res://demo/whitebox/grid.json"
    for arg in args:
        if arg.begins_with("--scene="):
            scene_path = arg.trim_prefix("--scene=")
        elif arg.begins_with("--grid="):
            grid_path = arg.trim_prefix("--grid=")
    var result: Dictionary
    if not FileAccess.file_exists(scene_path):
        result = {"summary": {"nodes": 0, "off_grid": 0, "walk_points": 0, "issues": 1}, "issues": [{"severity": "error", "kind": "missing_file", "path": scene_path, "message": "Scene not found: %s" % scene_path, "fix": "Check the --scene path."}]}
    else:
        var nodes := op.parse_scene(FileAccess.get_file_as_string(scene_path))
        var config: Dictionary = {}
        if FileAccess.file_exists(grid_path):
            var parsed = JSON.parse_string(FileAccess.get_file_as_string(grid_path))
            if typeof(parsed) == TYPE_DICTIONARY:
                config = parsed
        result = op.run(nodes, config)
    _emit(op, result, args, "res://reports/whitebox", ["errors","off_grid","steep_slope","missing_file"])


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
        _write(out_dir.path_join("whitebox.json"), op.to_json(result))
    if formats.has("md"):
        _write(out_dir.path_join("whitebox.md"), op.to_markdown(result))
    print("WBX summary: ", result.get("summary", {}))
    for i in result.get("issues", []):
        print("WBX [", i.get("severity", "info"), "] ", i.get("message", ""))
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
