extends SceneTree
const Core := preload("res://addons/test_priority/core/priority_plan.gd")

func _init() -> void:
    var first := "res://demo/test_priority/mapping.json"
    var second := "res://demo/test_priority/changes.json"
    var out := "res://reports/test_priority"
    var fail_on: Array = []
    var graph := ""
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--first="):
            first = arg.trim_prefix("--first=")
        elif arg.begins_with("--second="):
            second = arg.trim_prefix("--second=")
        elif arg.begins_with("--out="):
            out = arg.trim_prefix("--out=")
        elif arg.begins_with("--graph="):
            graph = arg.trim_prefix("--graph=")
        elif arg.begins_with("--fail-on="):
            fail_on = Array(arg.trim_prefix("--fail-on=").split(","))
    var op = Core.new()
    var result: Dictionary = op.run(first, second, graph)
    if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out)) != OK:
        printerr("Cannot create report directory: ", out)
        quit(1)
        return
    for pair in [["test_priority.json", op.to_json(result)], ["test_priority.md", op.to_markdown(result)]]:
        var file := FileAccess.open(out.path_join(pair[0]), FileAccess.WRITE)
        if file == null:
            printerr("Cannot write report: ", out.path_join(pair[0]))
            quit(1)
            return
        file.store_string(pair[1])
    print("Regression Test Prioritizer: ", result["summary"])
    var failed := false
    var error := false
    for issue in result["issues"]:
        print("[", issue["kind"], "] ", issue["path"], ": ", issue["message"])
        if issue["severity"] == "error":
            error = true
        if issue["kind"] in fail_on or "issues" in fail_on:
            failed = true
    quit(1 if error else (2 if failed else 0))
