## CI and Headless Test Runner - discovery and results operation.
## The engine-agnostic half of running a project's tests from CI: it
## discovers test files, classifies them (this project's extend-SceneTree
## harness, GUT suites when a project has GUT installed - detected, never
## depended on), builds the exact headless command lines to run them,
## converts result records to JUnit XML that GitHub Actions and friends
## render natively, and in check mode classifies --check-only output into
## parse errors versus warnings. Discovery, planning, classification and
## XML are pure data operations; the CLI (cli/ctr_cli.gd) does the actual
## OS.execute calls. tests/run_tests.sh remains the source of truth for
## this repo's own suite - this tool is for the games that import it.
extends RefCounted

var test_dirs: Array[String] = ["res://tests"]
var test_prefix: String = "test_"


func find_tests() -> Array:
    var out: Array = []
    for root in test_dirs:
        _walk(root, out)
    out.sort()
    return out


func _walk(dir_path: String, out: Array) -> void:
    var dir := DirAccess.open(dir_path)
    if dir == null:
        return
    dir.list_dir_begin()
    var name := dir.get_next()
    while name != "":
        if name.begins_with("."):
            name = dir.get_next()
            continue
        var full := dir_path.path_join(name)
        if dir.current_is_dir():
            _walk(full, out)
        elif name.get_extension() == "gd" and name.begins_with(test_prefix):
            out.append(full)
        name = dir.get_next()
    dir.list_dir_end()


## Classify one test file from its text: harness or GUT, and how many
## checks it promises (harness only).
func classify(text: String) -> Dictionary:
    var kind := "unknown"
    if "extends GutTest" in text or "extends \"res://addons/gut/test.gd\"" in text:
        kind = "gut"
    elif "extends SceneTree" in text:
        kind = "harness"
    var checks := text.count("_check(")
    var has_finish := "_finish(" in text
    return {"kind": kind, "checks": checks, "has_finish": has_finish}


## Pure: build the run plan - one command line per discovered test.
func plan(tests: Array, classifications: Dictionary, executable: String = "godot") -> Array:
    var rows: Array = []
    for path in tests:
        var c: Dictionary = classifications.get(str(path), {"kind": "unknown"})
        var cmd: Array = []
        match str(c["kind"]):
            "harness":
                cmd = [executable, "--headless", "--path", ".", "--script", str(path)]
            "gut":
                cmd = [executable, "--headless", "--path", ".", "-s",
                    "res://addons/gut/gut_cmdln.gd", "-gtest=" + str(path), "-gexit"]
            _:
                cmd = [executable, "--headless", "--path", ".", "--check-only", "--script", str(path)]
        rows.append({"path": str(path), "kind": str(c["kind"]), "command": cmd})
    return rows


## Pure: classify --check-only output.
func classify_check_output(output: String, exit_code: int) -> Dictionary:
    var errors: Array = []
    var warnings: Array = []
    for raw in output.split("\n"):
        var line := raw.strip_edges()
        if line.begins_with("ERROR:") or "Parse Error" in line or "SCRIPT ERROR" in line:
            errors.append(line)
        elif line.begins_with("WARNING:"):
            warnings.append(line)
    return {"ok": exit_code == 0 and errors.is_empty(), "exit_code": exit_code,
        "errors": errors, "warnings": warnings}


## Pure: result records -> JUnit XML string.
## results: [{suite, passed, failed, checks, seconds, failures: [msg]}]
func to_junit(results: Array) -> String:
    var total_tests := 0
    var total_failures := 0
    var total_time := 0.0
    for r in results:
        total_tests += int(r.get("passed", 0)) + int(r.get("failed", 0))
        total_failures += int(r.get("failed", 0))
        total_time += float(r.get("seconds", 0.0))
    var lines: Array[String] = ["<?xml version=\"1.0\" encoding=\"UTF-8\"?>",
        "<testsuites tests=\"%d\" failures=\"%d\" time=\"%.3f\">" % [total_tests, total_failures, total_time]]
    for r in results:
        var passed := int(r.get("passed", 0))
        var failed := int(r.get("failed", 0))
        lines.append("  <testsuite name=\"%s\" tests=\"%d\" failures=\"%d\" time=\"%.3f\">" % [
            _xml(str(r.get("suite", "suite"))), passed + failed, failed, float(r.get("seconds", 0.0))])
        for msg in r.get("failures", []):
            lines.append("    <testcase name=\"%s\" classname=\"%s\">" % [
                _xml(_failure_name(str(msg))), _xml(str(r.get("suite", "suite")))])
            lines.append("      <failure message=\"%s\"></failure>" % _xml(str(msg)))
            lines.append("    </testcase>")
        if failed == 0:
            lines.append("    <testcase name=\"all_checks\" classname=\"%s\"/>" % _xml(str(r.get("suite", "suite"))))
        lines.append("  </testsuite>")
    lines.append("</testsuites>")
    return "\n".join(lines) + "\n"


func _failure_name(msg: String) -> String:
    var i := msg.find(":")
    return msg.substr(0, i) if i > 0 else msg


func _xml(s: String) -> String:
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;")


## The one operation: discover, classify, plan; report projects with no
## tests and harness files missing _finish (they would hang CI).
func run() -> Dictionary:
    var issues: Array = []
    var tests := find_tests()
    if tests.is_empty():
        issues.append({"severity": "error", "kind": "no_tests_found", "path": ", ".join(test_dirs),
            "message": "No %s*.gd files under %s." % [test_prefix, ", ".join(test_dirs)],
            "fix": "Add test files, or point the runner at the directory that holds them (--dirs)."})
    var classifications: Dictionary = {}
    var kinds: Dictionary = {}
    for path in tests:
        var text := FileAccess.get_file_as_string(str(path))
        var c := classify(text)
        classifications[str(path)] = c
        kinds[str(c["kind"])] = int(kinds.get(str(c["kind"]), 0)) + 1
        if str(c["kind"]) == "harness" and not bool(c["has_finish"]):
            issues.append({"severity": "warning", "kind": "no_finish", "path": str(path),
                "message": "%s extends SceneTree but never calls _finish()/quit() - it would hang a CI job until the timeout kills it." % path,
                "fix": "End the script's run with quit(exit_code), as every test in this repo does."})
        if str(c["kind"]) == "unknown":
            issues.append({"severity": "info", "kind": "unclassified", "path": str(path),
                "message": "%s is neither a SceneTree harness nor a GUT suite; the plan falls back to --check-only." % path,
                "fix": "Make it extend SceneTree (harness) or GutTest (GUT), or exclude it from discovery."})
    var plan_rows := plan(tests, classifications, "godot")
    return {"summary": {"tests": tests.size(), "harness": int(kinds.get("harness", 0)),
            "gut": int(kinds.get("gut", 0)), "unknown": int(kinds.get("unknown", 0)),
            "issues": issues.size()},
        "plan": plan_rows, "issues": issues}


func to_json(result: Dictionary) -> String:
    return JSON.stringify({"summary": result["summary"], "issues": result["issues"],
        "plan": result.get("plan", [])}, "\t")


func to_markdown(result: Dictionary) -> String:
    var s: Dictionary = result["summary"]
    var lines: Array[String] = ["# Test Runner Report", "",
        "%d test file(s): %d harness, %d GUT, %d unclassified. %d problems." % [
            s["tests"], s["harness"], s["gut"], s["unknown"], s["issues"]], ""]
    for i in result["issues"]:
        lines.append("- [%s] %s" % [i["severity"], i["message"]])
    lines.append("")
    lines.append("## Run plan")
    for row in result.get("plan", []):
        lines.append("- `%s`" % " ".join(row["command"]))
    return "\n".join(lines) + "\n"
