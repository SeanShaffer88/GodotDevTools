extends SceneTree
const Simulator := preload("res://addons/flag_simulator/core/flag_simulator.gd")

func _init() -> void:
    var config := "res://demo/flags/flags.json"
    var subject := "demo-subject"
    var out := "res://reports/flag_simulator"
    var available := true
    var fail_on: Array = []
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--config="):
            config = arg.trim_prefix("--config=")
        elif arg.begins_with("--subject="):
            subject = arg.trim_prefix("--subject=")
        elif arg.begins_with("--out="):
            out = arg.trim_prefix("--out=")
        elif arg.begins_with("--fail-on="):
            fail_on = Array(arg.trim_prefix("--fail-on=").split(","))
        elif arg == "--unavailable":
            available = false
    var op = Simulator.new()
    var result: Dictionary = op.run(config, subject, available)
    if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out)) != OK:
        printerr("Cannot create report directory: ", out)
        quit(1)
        return
    for pair in [["flag_simulator.json", op.to_json(result)], ["flag_simulator.md", op.to_markdown(result)]]:
        var file := FileAccess.open(out.path_join(pair[0]), FileAccess.WRITE)
        if file == null:
            printerr("Cannot write report: ", out.path_join(pair[0]))
            quit(1)
            return
        file.store_string(pair[1])
    print("Flag simulator: ", result["summary"])
    var failed := false
    for issue in result["issues"]:
        print("[%s] %s: %s" % [issue["kind"], issue["path"], issue["message"]])
        if issue["kind"] == "input_error":
            quit(1)
            return
        if issue["kind"] in fail_on or "issues" in fail_on or "errors" in fail_on:
            failed = true
    quit(2 if failed else 0)
