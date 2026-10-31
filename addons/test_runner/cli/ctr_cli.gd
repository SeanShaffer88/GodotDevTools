## CI and Headless Test Runner - headless CLI.
##   godot --headless --path . --script res://addons/test_runner/cli/ctr_cli.gd -- [--out=<dir>] [--format=json,md] [--dirs=res://tests] [--check] [--junit=<file>] [--fail-on=errors,no_tests_found]
extends SceneTree

const Core := preload("res://addons/test_runner/core/ctr_runner.gd")


func _init() -> void:
    var args := OS.get_cmdline_user_args()
    var op = Core.new()
    for arg in args:
        if arg.begins_with("--dirs="):
            op.test_dirs.assign(arg.trim_prefix("--dirs=").split(","))
    var result: Dictionary = op.run()
    var check_mode := false
    var junit_path := ""
    for arg in args:
        if arg == "--check":
            check_mode = true
        elif arg.begins_with("--junit="):
            junit_path = arg.trim_prefix("--junit=")
    if check_mode:
        var exe := OS.get_executable_path()
        var records: Array = []
        for row_raw in result["plan"]:
            var row: Dictionary = row_raw
            var out_lines: Array = []
            var code := OS.execute(exe, ["--headless", "--path", ".", "--check-only", "--script", str(row["path"])], out_lines, true)
            var verdict := op.classify_check_output("\n".join(out_lines), code)
            records.append({"suite": str(row["path"]), "passed": 1 if bool(verdict["ok"]) else 0,
                "failed": 0 if bool(verdict["ok"]) else 1, "seconds": 0.0,
                "failures": verdict["errors"]})
            for w in verdict["warnings"]:
                result["issues"].append({"severity": "info", "kind": "warnings", "path": str(row["path"]), "message": str(w), "fix": ""})
            if not bool(verdict["ok"]):
                result["issues"].append({"severity": "error", "kind": "script_error", "path": str(row["path"]),
                    "message": "--check-only failed with exit %d" % code, "fix": "Fix the parse errors listed above."})
        result["summary"]["checked"] = records.size()
        result["summary"]["issues"] = (result["issues"] as Array).size()
        if junit_path != "":
            _write(junit_path, op.to_junit(records))
    _emit(op, result, args, "res://reports/test_runner", ["errors","no_tests_found","no_finish","script_error","unclassified"])


func _write(path: String, content: String) -> bool:
    var f := FileAccess.open(path, FileAccess.WRITE)
    if f == null:
        printerr("Could not write ", path)
        return false
    f.store_string(content)
    f.close()
    return true


func _emit(op, result: Dictionary, args: Array, default_out: String, fail_kinds: Array) -> void:
    var out_dir := default_out
    var formats: Array[String] = ["json", "md"]
    for arg in args:
        if arg.begins_with("--out="):
            out_dir = arg.trim_prefix("--out=")
        elif arg.begins_with("--format="):
            formats.assign(arg.trim_prefix("--format=").split(","))
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
    if formats.has("json"):
        _write(out_dir.path_join("test_runner.json"), op.to_json(result))
    if formats.has("md"):
        _write(out_dir.path_join("test_runner.md"), op.to_markdown(result))
    print("CTR summary: ", result.get("summary", {}))
    for i in result.get("issues", []):
        print("CTR [", i.get("severity", "info"), "] ", i.get("message", ""))
    var failed := false
    var fail_on: Array[String] = []
    for arg in args:
        if arg.begins_with("--fail-on="):
            fail_on.assign(arg.trim_prefix("--fail-on=").split(","))
    for k in fail_kinds:
        if fail_on.has(k):
            for i in result.get("issues", []):
                if i.get("kind", "") == k:
                    failed = true
    if fail_on.has("errors"):
        for i in result.get("issues", []):
            if i.get("severity", "") == "error":
                failed = true
    if fail_on.has("issues") and not (result.get("issues", []) as Array).is_empty():
        failed = true
    quit(2 if failed else 0)
