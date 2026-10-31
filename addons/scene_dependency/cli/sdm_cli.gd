## Scene Dependency Map CLI. --root may be repeated for explicit entry points.
extends SceneTree
const Core := preload("res://addons/scene_dependency/core/sdm_graph.gd")

func _init() -> void:
    var args := OS.get_cmdline_user_args()
    var scan_dir := "res://"
    var roots: Array = []
    for arg in args:
        if arg.begins_with("--dir="): scan_dir = arg.trim_prefix("--dir=")
        elif arg.begins_with("--root="): roots.append(arg.trim_prefix("--root="))
    var op = Core.new()
    var result: Dictionary = op.run(scan_dir, roots)
    _emit(op, result, args, "res://reports/scene_dependency", ["missing_dependency", "cycle", "long_chain", "unused_candidate", "unresolved_uid", "no_roots"])

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
    var dir_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
    if dir_error != OK:
        printerr("Could not create report directory: ", out_dir)
        quit(1)
        return
    if formats.has("json") and not _write(out_dir.path_join("scene_dependency.json"), op.to_json(result)):
        quit(1)
        return
    if formats.has("md") and not _write(out_dir.path_join("scene_dependency.md"), op.to_markdown(result)):
        quit(1)
        return
    print("SDM summary: ", result.get("summary", {}))
    for i in result.get("issues", []):
        print("SDM [", i.get("severity", "info"), "] ", i.get("message", ""))
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
