## Hot-Reloadable Schema and Save-Game Migrator - headless CLI.
##   godot --headless --path . --script res://addons/schema_migrator/cli/smg_cli.gd -- [--out=<dir>] [--format=json,md] [--fail-on=errors,no_registry,unmigratable,missing_field,missing_file,bad_json]
extends SceneTree

const Core := preload("res://addons/schema_migrator/core/smg_registry.gd")


func _init() -> void:
    var args := OS.get_cmdline_user_args()
    var op = Core.new()
    var registry_path := "res://demo/schema/player_schema.json"
    var save_path := "res://demo/schema/old_save.json"
    for arg in args:
        if arg.begins_with("--registry="):
            registry_path = arg.trim_prefix("--registry=")
        elif arg.begins_with("--save="):
            save_path = arg.trim_prefix("--save=")
    var loaded := op.load_registry(registry_path)
    var result: Dictionary
    if not (loaded["errors"] as Array).is_empty():
        result = {"summary": {"from": 0, "to": 0, "applied": 0, "issues": (loaded["errors"] as Array).size()}, "issues": loaded["errors"]}
    elif not FileAccess.file_exists(save_path):
        result = {"summary": {"from": 0, "to": 0, "applied": 0, "issues": 1}, "issues": [{"severity": "error", "kind": "missing_file", "path": save_path, "message": "Save file not found: %s" % save_path, "fix": "Check the --save path."}]}
    else:
        var parsed = JSON.parse_string(FileAccess.get_file_as_string(save_path))
        if typeof(parsed) != TYPE_DICTIONARY:
            result = {"summary": {"from": 0, "to": 0, "applied": 0, "issues": 1}, "issues": [{"severity": "error", "kind": "bad_json", "path": save_path, "message": "Save file is not a JSON object: %s" % save_path, "fix": "Repair or replace the save file."}]}
        else:
            result = op.migrate(parsed)
    _emit(op, result, args, "res://reports/schema_migrator", ["errors","no_registry","unmigratable","missing_field","missing_file","bad_json"])


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
        _write(out_dir.path_join("schema_migrator.json"), op.to_json(result))
    if formats.has("md"):
        _write(out_dir.path_join("schema_migrator.md"), op.to_markdown(result))
    print("SMG summary: ", result.get("summary", {}))
    for i in result.get("issues", []):
        print("SMG [", i.get("severity", "info"), "] ", i.get("message", ""))
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
