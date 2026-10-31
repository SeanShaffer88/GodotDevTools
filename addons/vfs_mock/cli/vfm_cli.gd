## Cross-Platform Virtual Filesystem Mock - headless CLI.
##   godot --headless --path . --script res://addons/vfs_mock/cli/vfm_cli.gd -- [--out=<dir>] [--format=json,md] [--fail-on=errors,case_collision,case_mismatch,sandbox_escape,permission_denied,reserved_name,forbidden_char,too_long,path_traversal,backslash_path,drive_letter]
extends SceneTree

const Core := preload("res://addons/vfs_mock/core/vfm_fs.gd")


func _init() -> void:
    var args := OS.get_cmdline_user_args()
    var op = Core.new()
    var requests: Array = []
    for arg in args:
        if arg.begins_with("--requests="):
            var req_path := arg.trim_prefix("--requests=")
            if FileAccess.file_exists(req_path):
                var parsed = JSON.parse_string(FileAccess.get_file_as_string(req_path))
                if typeof(parsed) == TYPE_ARRAY:
                    requests = parsed
    var result: Dictionary = op.run(requests)
    _emit(op, result, args, "res://reports/vfs_mock", ["errors","case_collision","case_mismatch","sandbox_escape","permission_denied","reserved_name","forbidden_char","too_long","path_traversal","backslash_path","drive_letter"])


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
        _write(out_dir.path_join("vfs_mock.json"), op.to_json(result))
    if formats.has("md"):
        _write(out_dir.path_join("vfs_mock.md"), op.to_markdown(result))
    print("VFM summary: ", result.get("summary", {}))
    for i in result.get("issues", []):
        print("VFM [", i.get("severity", "info"), "] ", i.get("message", ""))
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
