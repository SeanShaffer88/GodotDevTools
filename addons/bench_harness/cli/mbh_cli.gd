extends SceneTree
## Headless runner for Micro-Benchmark Harness. Thin shell: all checking lives in core/.
## Exit 2 when a --fail-on kind is found; 1 for bad arguments, unreadable input
## or report-write failure; otherwise 0.
const Core := preload("res://addons/bench_harness/core/mbh_harness.gd")
const KINDS := ["noisy_benchmark", "no_benchmarks", "bad_bench_script"]
const INPUT_ERRORS := ["bad_input", "no_benchmarks", "bad_bench_script"]

func _init() -> void:
    var input := "res://demo/ci/bench/bench_math.gd"
    var out := "res://reports/bench_harness"
    var fail_on: Array = []
    var options := {}
    for arg in OS.get_cmdline_user_args():
        var key := arg.get_slice("=", 0)
        var value := arg.substr(key.length() + 1) if arg.contains("=") else ""
        if key == "--script":
            input = value
        elif key == "--out":
            out = value
        elif key == "--fail-on":
            fail_on = Array(value.split(",", false))
        elif key == "--iterations":
            if not value.is_valid_int() or int(value) < 1:
                printerr("--iterations must be an integer >= 1.")
                quit(1)
                return
            options["iterations"] = int(value)
        elif key == "--warmup":
            if not value.is_valid_int() or int(value) < 0:
                printerr("--warmup must be an integer >= 0.")
                quit(1)
                return
            options["warmup"] = int(value)
        elif key == "--max-cv":
            if not value.is_valid_float() or float(value) < 0:
                printerr("--max-cv must be a number >= 0.")
                quit(1)
                return
            options["max_cv"] = float(value)
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
    for pair in [["bench_harness.json", op.to_json(result)], ["bench_harness.md", op.to_markdown(result)]]:
        var file := FileAccess.open(out.path_join(pair[0]), FileAccess.WRITE)
        if file == null:
            printerr("Cannot write report: ", out.path_join(pair[0]))
            quit(1)
            return
        file.store_string(pair[1])
    print("Micro-Benchmark Harness: ", result["summary"])
    var failed := false
    var input_error := false
    for issue in result["issues"]:
        print("[%s] %s:%s %s" % [issue["kind"], issue.get("path", ""), issue.get("line", "-"), issue["message"]])
        if issue["kind"] in INPUT_ERRORS:
            input_error = true
        if issue["kind"] in fail_on or "issues" in fail_on or ("errors" in fail_on and issue["severity"] == "error"):
            failed = true
    quit(1 if input_error else (2 if failed else 0))
