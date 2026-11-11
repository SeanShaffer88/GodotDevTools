extends SceneTree
## Headless wrapper: checking lives in core/; exit 1 for input/write errors, 2 for a selected finding.
const Core := preload("res://addons/android_logcat_triage/core/alt_triage.gd")
const KINDS := ["java_crash", "native_crash", "anr", "no_matching_crashes", "unattributed_crashes", "incomplete_java_trace", "unsupported_lines", "event_limit"]


func _init() -> void:
    var input := "user://android_logcat.txt"
    var out := "res://reports/android_logcat_triage"
    var fail_on: Array = []
    var options := {}
    for arg in OS.get_cmdline_user_args():
        if arg == "--help":
            print("Android Logcat Crash Triage: [--log=VALUE] [--out=VALUE] [--fail-on=VALUE] [--package=VALUE]")
            quit(0)
            return
        var key := arg.get_slice("=", 0)
        var value := arg.substr(key.length() + 1) if arg.contains("=") else ""
        if key not in ["--log", "--out", "--fail-on", "--package"] or value.is_empty():
            printerr("Unknown or empty argument: ", key)
            quit(1)
            return
        if key == "--log":
            input = value
        elif key == "--out":
            out = value
        elif key == "--fail-on":
            fail_on = Array(value.split(",", true))
        elif key == "--package":
            options["package"] = value
    for kind in fail_on:
        if kind not in KINDS and kind not in ["issues", "errors"]:
            printerr("Unknown --fail-on kind: ", kind)
            quit(1)
            return
    var op = Core.new()
    var result: Dictionary = op.run(input, options)
    if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out)) != OK:
        printerr("Cannot create report directory: ", out)
        quit(1)
        return
    for pair in [["android_logcat_triage.json", op.to_json(result)], ["android_logcat_triage.md", op.to_markdown(result)]]:
        var file := FileAccess.open(out.path_join(pair[0]), FileAccess.WRITE)
        if file == null:
            printerr("Cannot write report: ", out.path_join(pair[0]))
            quit(1)
            return
        file.store_string(pair[1])
        var write_error := file.get_error()
        file.close()
        if write_error != OK:
            printerr("Cannot finish writing report: ", out.path_join(pair[0]))
            quit(1)
            return
    print("Android Logcat Crash Triage: ", result["summary"])
    var failed := false
    var input_error := false
    for issue in result["issues"]:
        print("[%s] %s:%s %s" % [issue["kind"], issue.get("path", ""), issue.get("line", 0), issue["message"]])
        if issue["kind"] == "bad_input":
            input_error = true
        if issue["kind"] in fail_on or "issues" in fail_on or ("errors" in fail_on and issue["severity"] == "error"):
            failed = true
    quit(1 if input_error else (2 if failed else 0))
