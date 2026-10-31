extends SceneTree
const Analyzer := preload("res://addons/build_size/core/bs_analyzer.gd")

func _init() -> void:
    var root := "res://demo/build_size"
    var out := "res://reports/build_size"
    var max_file := 0
    var max_total := 0
    var fail_on: Array = []
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--dir="):
            root = arg.trim_prefix("--dir=")
        elif arg.begins_with("--out="):
            out = arg.trim_prefix("--out=")
        elif arg.begins_with("--max-file="):
            var value := arg.trim_prefix("--max-file=")
            if not value.is_valid_int():
                printerr("Invalid --max-file byte budget")
                quit(1)
                return
            max_file = int(value)
        elif arg.begins_with("--max-total="):
            var value := arg.trim_prefix("--max-total=")
            if not value.is_valid_int():
                printerr("Invalid --max-total byte budget")
                quit(1)
                return
            max_total = int(value)
        elif arg.begins_with("--fail-on="):
            fail_on = Array(arg.trim_prefix("--fail-on=").split(","))
    var op = Analyzer.new()
    var result: Dictionary = op.run(root, max_file, max_total)
    if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out)) != OK:
        printerr("Cannot create report directory: ", out)
        quit(1)
        return
    for pair in [["build_size.json", op.to_json(result)], ["build_size.md", op.to_markdown(result)]]:
        var file := FileAccess.open(out.path_join(pair[0]), FileAccess.WRITE)
        if file == null:
            printerr("Cannot write report: ", out.path_join(pair[0]))
            quit(1)
            return
        file.store_string(pair[1])
    print("Build size: ", result["summary"])
    var failed := false
    var error := false
    for issue in result["issues"]:
        print("[%s] %s: %s" % [issue["kind"], issue["path"], issue["message"]])
        if issue["severity"] == "error":
            error = true
        if issue["kind"] in fail_on or "issues" in fail_on:
            failed = true
    quit(1 if error else (2 if failed else 0))
