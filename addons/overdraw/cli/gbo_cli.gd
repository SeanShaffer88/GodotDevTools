extends SceneTree
## Headless runner for GPU Budget and Overdraw Analyzer. Thin shell: all checking lives in core/.
## Exit 2 when a --fail-on kind is found; 1 for bad arguments, unreadable input
## or report-write failure; otherwise 0.
const Core := preload("res://addons/overdraw/core/gbo_analyzer.gd")
const KINDS := ["overdraw_budget", "stacked_fullscreen"]
const INPUT_ERRORS := ["scan_error", "bad_input"]

func _init() -> void:
    var input := "res://"
    var out := "res://reports/overdraw"
    var fail_on: Array = []
    var options := {}
    for arg in OS.get_cmdline_user_args():
        var key := arg.get_slice("=", 0)
        var value := arg.substr(key.length() + 1) if arg.contains("=") else ""
        if key == "--dir":
            input = value
        elif key == "--out":
            out = value
        elif key == "--fail-on":
            fail_on = Array(value.split(",", false))
        elif key == "--width":
            if not value.is_valid_int() or int(value) < 1:
                printerr("--width must be an integer >= 1.")
                quit(1)
                return
            options["width"] = int(value)
        elif key == "--height":
            if not value.is_valid_int() or int(value) < 1:
                printerr("--height must be an integer >= 1.")
                quit(1)
                return
            options["height"] = int(value)
        elif key == "--max-overdraw":
            if not value.is_valid_float() or float(value) < 0:
                printerr("--max-overdraw must be a number >= 0.")
                quit(1)
                return
            options["max_overdraw"] = float(value)
        elif key == "--fps":
            if not value.is_valid_int() or int(value) < 1:
                printerr("--fps must be an integer >= 1.")
                quit(1)
                return
            options["fps"] = int(value)
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
    var result: Dictionary = op.run(input, options)
    var artifacts: Dictionary = result.get("artifacts", {})
    result.erase("artifacts")
    if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out)) != OK:
        printerr("Cannot create report directory: ", out)
        quit(1)
        return
    for name in artifacts.keys():
        var art := FileAccess.open(out.path_join(name), FileAccess.WRITE)
        if art == null:
            printerr("Cannot write: ", out.path_join(name))
            quit(1)
            return
        art.store_string(str(artifacts[name]))
        print("Wrote ", out.path_join(name))
    for pair in [["overdraw.json", op.to_json(result)], ["overdraw.md", op.to_markdown(result)]]:
        var file := FileAccess.open(out.path_join(pair[0]), FileAccess.WRITE)
        if file == null:
            printerr("Cannot write report: ", out.path_join(pair[0]))
            quit(1)
            return
        file.store_string(pair[1])
    print("GPU Budget and Overdraw Analyzer: ", result["summary"])
    var failed := false
    var input_error := false
    for issue in result["issues"]:
        print("[%s] %s:%s %s" % [issue["kind"], issue.get("path", ""), issue.get("line", "-"), issue["message"]])
        if issue["kind"] in INPUT_ERRORS:
            input_error = true
        if issue["kind"] in fail_on or "issues" in fail_on or ("errors" in fail_on and issue["severity"] == "error"):
            failed = true
    quit(1 if input_error else (2 if failed else 0))
