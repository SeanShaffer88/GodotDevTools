extends SceneTree
const Core := preload("res://addons/particle_budget/core/pbi_scanner.gd")
const KINDS := ["scene_budget", "emitter_budget", "cpu_heavy", "preprocess_cost", "missing_scene", "instance_cycle"]

func _init() -> void:
    var dir := "res://"
    var out := "res://reports/particle_budget"
    var fail_on: Array = []
    var budget := {}
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--dir="):
            dir = arg.trim_prefix("--dir=")
        elif arg.begins_with("--out="):
            out = arg.trim_prefix("--out=")
        elif arg.begins_with("--fail-on="):
            fail_on = Array(arg.trim_prefix("--fail-on=").split(",", false))
        elif arg.begins_with("--max-scene=") or arg.begins_with("--max-emitter=") or arg.begins_with("--max-cpu-emitter="):
            var key := arg.get_slice("=", 0).trim_prefix("--").replace("-", "_")
            var value := arg.get_slice("=", 1)
            if not value.is_valid_int() or int(value) < 0:
                printerr("%s must be a non-negative integer." % arg.get_slice("=", 0))
                quit(1)
                return
            budget[key] = int(value)
        elif arg.begins_with("--max-preprocess="):
            var seconds := arg.trim_prefix("--max-preprocess=")
            if not seconds.is_valid_float() or float(seconds) < 0.0:
                printerr("--max-preprocess must be a non-negative number of seconds.")
                quit(1)
                return
            budget["max_preprocess"] = float(seconds)
        else:
            printerr("Unknown argument: ", arg)
            quit(1)
            return
    for kind in fail_on:
        if kind not in KINDS and kind not in ["issues", "errors"]:
            printerr("Unknown --fail-on kind: %s (expected %s, issues or errors)" % [kind, ", ".join(KINDS)])
            quit(1)
            return
    var op = Core.new()
    var result: Dictionary = op.run(dir, budget)
    if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out)) != OK:
        printerr("Cannot create report directory: ", out)
        quit(1)
        return
    for pair in [["particle_budget.json", op.to_json(result)], ["particle_budget.md", op.to_markdown(result)]]:
        var file := FileAccess.open(out.path_join(pair[0]), FileAccess.WRITE)
        if file == null:
            printerr("Cannot write report: ", out.path_join(pair[0]))
            quit(1)
            return
        file.store_string(pair[1])
    print("Particle budget: ", result["summary"])
    var failed := false
    for issue in result["issues"]:
        print("[%s] %s %s: %s" % [issue["kind"], issue["path"], issue["node"], issue["message"]])
        if issue["kind"] == "scan_error":
            quit(1)
            return
        if issue["kind"] in fail_on or "issues" in fail_on or ("errors" in fail_on and issue["severity"] == "error"):
            failed = true
    quit(2 if failed else 0)
