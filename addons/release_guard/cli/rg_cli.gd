extends SceneTree
const Core := preload("res://addons/release_guard/core/rg_scanner.gd")

func _init() -> void:
    var dir := "res://"
    var out := "res://reports/release_guard"
    var fail_on: Array = []
    var rules_path := ""
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--dir="):
            dir = arg.trim_prefix("--dir=")
        elif arg.begins_with("--out="):
            out = arg.trim_prefix("--out=")
        elif arg.begins_with("--rules="):
            rules_path = arg.trim_prefix("--rules=")
        elif arg.begins_with("--fail-on="):
            fail_on = Array(arg.trim_prefix("--fail-on=").split(","))
    var op = Core.new()
    var rules: Array = Core.DEFAULT_RULES
    if rules_path != "":
        if not FileAccess.file_exists(rules_path):
            printerr("Rules file not found: ", rules_path)
            quit(1)
            return
        var parsed = JSON.parse_string(FileAccess.get_file_as_string(rules_path))
        if typeof(parsed) != TYPE_ARRAY:
            printerr("Rules file must contain an array of marker objects.")
            quit(1)
            return
        for rule in parsed:
            if typeof(rule) != TYPE_DICTIONARY or typeof(rule.get("marker")) != TYPE_STRING or str(rule.get("marker", "")) == "":
                printerr("Every rule needs a non-empty string marker.")
                quit(1)
                return
        rules = parsed
    var result: Dictionary = op.run(dir, rules)
    if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out)) != OK:
        printerr("Cannot create report directory: ", out)
        quit(1)
        return
    for pair in [["release_guard.json", op.to_json(result)], ["release_guard.md", op.to_markdown(result)]]:
        var file := FileAccess.open(out.path_join(pair[0]), FileAccess.WRITE)
        if file == null:
            printerr("Cannot write report: ", out.path_join(pair[0]))
            quit(1)
            return
        file.store_string(pair[1])
    print("Release guard: ", result["summary"])
    var failed := false
    for issue in result["issues"]:
        print("[%s] %s: %s" % [issue["kind"], issue["path"], issue["message"]])
        if issue["kind"] == "scan_error":
            quit(1)
            return
        if issue["kind"] in fail_on or "issues" in fail_on or ("errors" in fail_on and issue["severity"] == "error"):
            failed = true
    quit(2 if failed else 0)
