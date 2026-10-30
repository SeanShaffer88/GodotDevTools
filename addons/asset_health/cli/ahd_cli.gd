## Asset Health Dashboard - headless CLI.
##   godot --headless --path . --script res://addons/asset_health/cli/ahd_cli.gd -- [--out=<dir>] [--fail-on=oversized_texture,duplicate,unused,import_inconsistent]
extends SceneTree

const Scanner := preload("res://addons/asset_health/core/ahd_scanner.gd")


func _init() -> void:
    var args := OS.get_cmdline_user_args()
    var op = Scanner.new()
    for arg in args:
        if arg.begins_with("--big-texture="):
            var px := int(arg.trim_prefix("--big-texture="))
            op.big_texture_pixels = px * px
    var result: Dictionary = op.scan()
    _emit(op, result, args, "res://reports/asset_health", ["oversized_texture", "duplicate", "unused", "import_inconsistent", "slow_load"])

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
        _write(out_dir.path_join("asset_health.json"), op.to_json(result))
    if formats.has("md"):
        _write(out_dir.path_join("asset_health.md"), op.to_markdown(result))
    print("AHD summary: ", result.get("summary", {}))
    for i in result.get("issues", []):
        print("AHD [", i.get("severity", "info"), "] ", i.get("message", ""))
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
