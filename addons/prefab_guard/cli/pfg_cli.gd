## Smart Prefab and Variant Instance Manager - headless CLI.
##   godot --headless --path . --script res://addons/prefab_guard/cli/pfg_cli.gd -- [--out=<dir>] [--format=json,md] [--fail-on=errors,drifted_property,default_drift,prefab_missing,missing_file]
extends SceneTree

const Core := preload("res://addons/prefab_guard/core/pfg_diff.gd")


func _init() -> void:
    var args := OS.get_cmdline_user_args()
    var op = Core.new()
    var scene_path := "res://demo/prefabs/room.tscn"
    var apply := false
    for arg in args:
        if arg.begins_with("--scene="):
            scene_path = arg.trim_prefix("--scene=")
        elif arg == "--apply":
            apply = true
    var result: Dictionary
    if not FileAccess.file_exists(scene_path):
        result = {"summary": {"instances": 0, "overrides": 0, "dead_overrides": 0, "hiding_overrides": 0, "issues": 1}, "plan": [], "issues": [{"severity": "error", "kind": "missing_file", "path": scene_path, "message": "Scene not found: %s" % scene_path, "fix": "Check the --scene path."}]}
    else:
        var scene_text := FileAccess.get_file_as_string(scene_path)
        var prefab_texts: Dictionary = {}
        var ext := op.parse_ext_scenes(scene_text)
        for id in ext:
            var p := str(ext[id])
            if FileAccess.file_exists(p):
                prefab_texts[p] = FileAccess.get_file_as_string(p)
        result = op.analyze(scene_text, scene_path, prefab_texts)
        if apply:
            var removed := 0
            var out_lines: Array[String] = []
            var current_node := ""
            for raw in scene_text.split("\n"):
                var stripped := raw.strip_edges()
                if stripped.begins_with("[node "):
                    current_node = op._attr(stripped, "name")
                var drop := false
                for op_row_raw in result["plan"]:
                    var op_row: Dictionary = op_row_raw
                    if str(op_row["op"]) == "remove_override" and str(op_row["node"]) == current_node and stripped.begins_with(str(op_row["prop"]) + " = "):
                        drop = true
                if drop:
                    removed += 1
                else:
                    out_lines.append(raw)
            var f := FileAccess.open(scene_path, FileAccess.WRITE)
            if f != null:
                f.store_string("\n".join(out_lines))
                f.close()
            print("PFG apply: removed ", removed, " dead override line(s) from ", scene_path)
    _emit(op, result, args, "res://reports/prefab_guard", ["errors","drifted_property","default_drift","prefab_missing","missing_file"])


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
        _write(out_dir.path_join("prefab_guard.json"), op.to_json(result))
    if formats.has("md"):
        _write(out_dir.path_join("prefab_guard.md"), op.to_markdown(result))
    print("PFG summary: ", result.get("summary", {}))
    for i in result.get("issues", []):
        print("PFG [", i.get("severity", "info"), "] ", i.get("message", ""))
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
