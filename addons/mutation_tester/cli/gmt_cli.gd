extends SceneTree
## Headless runner for GDScript Mutation Tester. Thin shell: all checking lives in core/.
## Exit 2 when a --fail-on kind is found; 1 for bad arguments, unreadable input
## or report-write failure; otherwise 0.
const Core := preload("res://addons/mutation_tester/core/gmt_mutator.gd")
const KINDS := ["survived_mutant", "baseline_failed", "timeout_mutant"]
const INPUT_ERRORS := ["bad_input", "baseline_failed"]

func _init() -> void:
    var input := "res://demo/ci/mutation/clamp_health.gd"
    var out := "res://reports/mutation_tester"
    var fail_on: Array = []
    var options := {}
    for arg in OS.get_cmdline_user_args():
        var key := arg.get_slice("=", 0)
        var value := arg.substr(key.length() + 1) if arg.contains("=") else ""
        if key == "--target":
            input = value
        elif key == "--out":
            out = value
        elif key == "--fail-on":
            fail_on = Array(value.split(",", false))
        elif key == "--test":
            options["test"] = value
        elif key == "--max-mutants":
            if not value.is_valid_int() or int(value) < 1:
                printerr("--max-mutants must be an integer >= 1.")
                quit(1)
                return
            options["max_mutants"] = int(value)
        elif key == "--timeout":
            if not value.is_valid_float() or float(value) < 1:
                printerr("--timeout must be a number >= 1.")
                quit(1)
                return
            options["timeout"] = float(value)
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
    if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out)) != OK:
        printerr("Cannot create report directory: ", out)
        quit(1)
        return
    for pair in [["mutation_tester.json", op.to_json(result)], ["mutation_tester.md", op.to_markdown(result)]]:
        var file := FileAccess.open(out.path_join(pair[0]), FileAccess.WRITE)
        if file == null:
            printerr("Cannot write report: ", out.path_join(pair[0]))
            quit(1)
            return
        file.store_string(pair[1])
    print("GDScript Mutation Tester: ", result["summary"])
    var failed := false
    var input_error := false
    for issue in result["issues"]:
        print("[%s] %s:%s %s" % [issue["kind"], issue.get("path", ""), issue.get("line", "-"), issue["message"]])
        if issue["kind"] in INPUT_ERRORS:
            input_error = true
        if issue["kind"] in fail_on or "issues" in fail_on or ("errors" in fail_on and issue["severity"] == "error"):
            failed = true
    quit(1 if input_error else (2 if failed else 0))
