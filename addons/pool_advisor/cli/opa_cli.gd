extends SceneTree
const Core := preload("res://addons/pool_advisor/core/opa_advisor.gd")
const KINDS := ["pool_candidate", "hot_spawn", "burst_spawn", "unresolved_spawn", "high_spawn_rate", "bad_counts"]

func _init() -> void:
    var dir := "res://"
    var out := "res://reports/pool_advisor"
    var fail_on: Array = []
    var counts := {}
    var options := {}
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--dir="):
            dir = arg.trim_prefix("--dir=")
        elif arg.begins_with("--out="):
            out = arg.trim_prefix("--out=")
        elif arg.begins_with("--fail-on="):
            fail_on = Array(arg.trim_prefix("--fail-on=").split(",", false))
        elif arg.begins_with("--counts="):
            var path := arg.trim_prefix("--counts=")
            if not FileAccess.file_exists(path):
                printerr("Counts file not found: ", path)
                quit(1)
                return
            var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
            if typeof(parsed) != TYPE_DICTIONARY:
                printerr("Counts file must be a JSON object.")
                quit(1)
                return
            counts = parsed
        elif arg.begins_with("--min-score="):
            var v := arg.trim_prefix("--min-score=")
            if not v.is_valid_int() or int(v) < 1:
                printerr("--min-score must be a positive integer.")
                quit(1)
                return
            options["min_score"] = int(v)
        elif arg.begins_with("--rate-threshold="):
            var r := arg.trim_prefix("--rate-threshold=")
            if not r.is_valid_float() or float(r) <= 0.0:
                printerr("--rate-threshold must be a positive number of spawns per second.")
                quit(1)
                return
            options["rate_threshold"] = float(r)
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
    var result: Dictionary = op.run(dir, counts, options)
    if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out)) != OK:
        printerr("Cannot create report directory: ", out)
        quit(1)
        return
    for pair in [["pool_advisor.json", op.to_json(result)], ["pool_advisor.md", op.to_markdown(result)]]:
        var file := FileAccess.open(out.path_join(pair[0]), FileAccess.WRITE)
        if file == null:
            printerr("Cannot write report: ", out.path_join(pair[0]))
            quit(1)
            return
        file.store_string(pair[1])
    print("Pool advisor: ", result["summary"])
    var failed := false
    for issue in result["issues"]:
        print("[%s] %s:%d %s" % [issue["kind"], issue["path"], issue["line"], issue["message"]])
        if issue["kind"] in ["scan_error", "bad_counts"]:
            quit(1)
            return
        if issue["kind"] in fail_on or "issues" in fail_on or ("errors" in fail_on and issue["severity"] == "error"):
            failed = true
    quit(2 if failed else 0)
