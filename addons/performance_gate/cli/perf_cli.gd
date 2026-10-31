extends SceneTree
const Compare := preload("res://addons/performance_gate/core/perf_compare.gd")

func _init() -> void:
    var baseline := "res://demo/performance/baseline.json"
    var current := "res://demo/performance/current.json"
    var out := "res://reports/performance_gate"
    var fail_on: Array = []
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--baseline="):
            baseline = arg.trim_prefix("--baseline=")
        elif arg.begins_with("--current="):
            current = arg.trim_prefix("--current=")
        elif arg.begins_with("--out="):
            out = arg.trim_prefix("--out=")
        elif arg.begins_with("--fail-on="):
            fail_on = Array(arg.trim_prefix("--fail-on=").split(","))
    var op = Compare.new()
    var result: Dictionary = op.run(baseline, current)
    if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out)) != OK:
        printerr("Cannot create report directory: ", out)
        quit(1)
        return
    for pair in [["performance_gate.json", op.to_json(result)], ["performance_gate.md", op.to_markdown(result)]]:
        var file := FileAccess.open(out.path_join(pair[0]), FileAccess.WRITE)
        if file == null:
            printerr("Cannot write report: ", out.path_join(pair[0]))
            quit(1)
            return
        file.store_string(pair[1])
    print("Performance gate: ", result["summary"])
    var failed := false
    var error := false
    for issue in result["issues"]:
        print("[%s] %s: %s" % [issue["kind"], issue["path"], issue["message"]])
        if issue["severity"] == "error":
            error = true
        if issue["kind"] in fail_on or "issues" in fail_on:
            failed = true
    quit(1 if error else (2 if failed else 0))
