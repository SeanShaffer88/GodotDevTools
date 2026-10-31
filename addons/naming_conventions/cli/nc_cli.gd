extends SceneTree
const Audit := preload("res://addons/naming_conventions/core/nc_audit.gd")

func _init() -> void:
    var root := "res://"
    var pattern := Audit.DEFAULT_PATTERN
    var out := "res://reports/naming_conventions"
    var fail_on: Array = []
    var symbols := false
    var symbol_patterns := {}
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--dir="):
            root = arg.trim_prefix("--dir=")
        elif arg.begins_with("--pattern="):
            pattern = arg.trim_prefix("--pattern=")
        elif arg == "--symbols":
            symbols = true
        elif arg.begins_with("--node-pattern="):
            symbol_patterns["node_name"] = arg.trim_prefix("--node-pattern=")
        elif arg.begins_with("--signal-pattern="):
            symbol_patterns["signal_name"] = arg.trim_prefix("--signal-pattern=")
        elif arg.begins_with("--group-pattern="):
            symbol_patterns["group_name"] = arg.trim_prefix("--group-pattern=")
        elif arg.begins_with("--out="):
            out = arg.trim_prefix("--out=")
        elif arg.begins_with("--fail-on="):
            fail_on = Array(arg.trim_prefix("--fail-on=").split(","))
    var op = Audit.new()
    var result: Dictionary = op.run(root, pattern, symbols, symbol_patterns)
    if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out)) != OK:
        printerr("Cannot create report directory: ", out)
        quit(1)
        return
    for pair in [["naming_conventions.json", op.to_json(result)], ["naming_conventions.md", op.to_markdown(result)]]:
        var file := FileAccess.open(out.path_join(pair[0]), FileAccess.WRITE)
        if file == null:
            printerr("Cannot write report: ", out.path_join(pair[0]))
            quit(1)
            return
        file.store_string(pair[1])
    print("Naming conventions: ", result["summary"])
    var failed := false
    for issue in result["issues"]:
        print("[%s] %s: %s" % [issue["kind"], issue["path"], issue["message"]])
        if issue["severity"] == "error":
            quit(1)
            return
        if issue["kind"] in fail_on or "issues" in fail_on:
            failed = true
    quit(2 if failed else 0)
