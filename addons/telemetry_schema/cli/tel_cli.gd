extends SceneTree
const Validator := preload("res://addons/telemetry_schema/core/tel_validator.gd")

func _init() -> void:
    var schema := "res://demo/telemetry/schema.json"
    var samples := "res://demo/telemetry/events.json"
    var out := "res://reports/telemetry_schema"
    var fail_on: Array = []
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--schema="):
            schema = arg.trim_prefix("--schema=")
        elif arg.begins_with("--samples="):
            samples = arg.trim_prefix("--samples=")
        elif arg.begins_with("--out="):
            out = arg.trim_prefix("--out=")
        elif arg.begins_with("--fail-on="):
            fail_on = Array(arg.trim_prefix("--fail-on=").split(","))
    var op = Validator.new()
    var result: Dictionary = op.run(schema, samples)
    if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out)) != OK:
        printerr("Cannot create report directory: ", out)
        quit(1)
        return
    for pair in [["telemetry_schema.json", op.to_json(result)], ["telemetry_schema.md", op.to_markdown(result)]]:
        var file := FileAccess.open(out.path_join(pair[0]), FileAccess.WRITE)
        if file == null:
            printerr("Cannot write report: ", out.path_join(pair[0]))
            quit(1)
            return
        file.store_string(pair[1])
    print("Telemetry schema: ", result["summary"])
    var failed := false
    var error := false
    for issue in result["issues"]:
        print("[%s] %s: %s" % [issue["kind"], issue["path"], issue["message"]])
        if issue["severity"] == "error":
            error = true
        if issue["kind"] in fail_on or "issues" in fail_on:
            failed = true
    quit(1 if error else (2 if failed else 0))
