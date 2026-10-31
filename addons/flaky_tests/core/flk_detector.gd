## Flaky Test Detector - run history analysis.
## Each run is a JUnit XML file (testsuite/testcase with failure, error or
## skipped children; a "commit" property identifies the code under test) or
## an entry of a JSON history. A test that passes and fails on the same
## commit is flaky by definition; frequent flips across commits are a
## weaker signal. Skipped results are ignored.
extends RefCounted

const EXTS: Array[String] = ["xml"]
const DEFAULTS := {"flip_rate": 0.3}


func run(input: String = "", options: Dictionary = {}) -> Dictionary:
    var runs: Array = []
    if input.get_extension() == "json":
        var data: Variant = _read_json(input)
        if typeof(data) != TYPE_DICTIONARY or typeof(data.get("runs")) != TYPE_ARRAY:
            return _fail(input, "History missing or without a runs array.", "See the README for the JSON format.", "bad_input")
        runs = data["runs"]
    elif DirAccess.open(input) != null:
        var paths: Array = []
        _walk(input, paths)
        paths.sort()
        for p in paths:
            var r := parse_junit(FileAccess.get_file_as_bytes(p))
            r["id"] = str(p).get_file()
            runs.append(r)
    else:
        return _fail(input, "Not a folder of JUnit XML or a JSON history.", "Pass --input=<folder or history.json>.", "bad_input")
    return evaluate(runs, options)


## One JUnit XML document -> {commit, results: {name: pass|fail|skip}}.
func parse_junit(bytes: PackedByteArray) -> Dictionary:
    var out := {"commit": "", "results": {}}
    var parser := XMLParser.new()
    if parser.open_buffer(bytes) != OK:
        return out
    var current := ""
    while parser.read() == OK:
        var t := parser.get_node_type()
        if t == XMLParser.NODE_ELEMENT:
            var name := parser.get_node_name()
            if name == "property" and parser.get_named_attribute_value_safe("name") == "commit":
                out["commit"] = parser.get_named_attribute_value_safe("value")
            elif name == "testcase":
                var cls := parser.get_named_attribute_value_safe("classname")
                current = (cls + "." if cls != "" else "") + parser.get_named_attribute_value_safe("name")
                out["results"][current] = "pass"
                if parser.is_empty():
                    current = ""
            elif current != "" and name in ["failure", "error"]:
                out["results"][current] = "fail"
            elif current != "" and name == "skipped":
                out["results"][current] = "skip"
        elif t == XMLParser.NODE_ELEMENT_END and parser.get_node_name() == "testcase":
            current = ""
    return out


func evaluate(runs: Array, options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    var issues: Array = []
    var history := {}  # test -> [[commit, outcome]]
    for r in runs:
        var results: Dictionary = r.get("results", {}) if typeof(r) == TYPE_DICTIONARY else {}
        for test in results.keys():
            var outcome := str(results[test])
            if outcome not in ["pass", "fail"]:
                continue
            if not history.has(test):
                history[test] = []
            history[test].append([str(r.get("commit", "")), outcome])
    var names: Array = history.keys()
    names.sort()
    var rows: Array = []
    for test in names:
        var h: Array = history[test]
        var by_commit := {}
        var flips := 0
        var fails := 0
        for i in range(h.size()):
            if h[i][1] == "fail":
                fails += 1
            if i > 0 and h[i][1] != h[i - 1][1]:
                flips += 1
            if h[i][0] != "":
                if not by_commit.has(h[i][0]):
                    by_commit[h[i][0]] = {}
                by_commit[h[i][0]][h[i][1]] = true
        var mixed: Array = by_commit.keys().filter(func(c): return by_commit[c].size() == 2)
        var rate := 0.0 if h.size() < 2 else float(flips) / (h.size() - 1)
        rows.append({"test": test, "runs": h.size(), "fails": fails, "flip_rate": snappedf(rate, 0.01)})
        if not mixed.is_empty():
            issues.append(_issue("warning", "flaky_same_commit", test, 0, "Passed and failed on the same commit (%s); %d of %d runs failed." % [", ".join(mixed), fails, h.size()], "Look for timing, ordering, randomness or shared state; quarantine it until fixed."))
        elif rate >= float(opts["flip_rate"]) and h.size() >= 3:
            issues.append(_issue("info", "high_flip_rate", test, 0, "Outcome flipped in %.0f%% of consecutive runs." % (rate * 100.0), "Re-run on one commit to confirm flakiness."))
        if fails == h.size() and h.size() >= 2:
            issues.append(_issue("info", "always_failing", test, 0, "Failed in all %d runs." % h.size(), "Not flaky - broken. Fix or remove it."))
    return _finish({"runs": runs.size(), "tests": rows.size()}, issues, {"tests": rows})


func _walk(path: String, out: Array) -> void:
    var dir := DirAccess.open(path)
    if dir == null:
        return
    dir.list_dir_begin()
    var name := dir.get_next()
    while name != "":
        if not name.begins_with(".") and name not in ["addons", "reports", "visual_reports"]:
            var child := path.path_join(name)
            if dir.current_is_dir():
                _walk(child, out)
            elif name.get_extension().to_lower() in EXTS:
                out.append(child)
        name = dir.get_next()
    dir.list_dir_end()


func _opts(options: Dictionary) -> Dictionary:
    var merged: Dictionary = DEFAULTS.duplicate(true)
    merged.merge(options, true)
    return merged


func _read_json(path: String) -> Variant:
    if not FileAccess.file_exists(path):
        return null
    return JSON.parse_string(FileAccess.get_file_as_string(path))


func _issue(severity: String, kind: String, path: String, line: int, message: String, fix: String) -> Dictionary:
    return {"severity": severity, "kind": kind, "path": path, "line": line, "message": message, "fix": fix}


func _fail(path: String, message: String, fix: String, kind: String = "scan_error") -> Dictionary:
    return {"summary": {"issues": 1}, "issues": [_issue("error", kind, path, 0, message, fix)]}


func _finish(summary: Dictionary, issues: Array, extra: Dictionary = {}) -> Dictionary:
    issues.sort_custom(func(a, b): return "%s|%08d|%s" % [a["path"], int(a["line"]), a["kind"]] < "%s|%08d|%s" % [b["path"], int(b["line"]), b["kind"]])
    summary["issues"] = issues.size()
    var result := {"summary": summary, "issues": issues}
    result.merge(extra)
    return result


func _count(result: Dictionary, kind: String) -> int:
    var n := 0
    for issue in result["issues"]:
        if issue["kind"] == kind:
            n += 1
    return n


func to_json(result: Dictionary) -> String:
    return JSON.stringify(result, "  ")


func to_markdown(result: Dictionary) -> String:
    var lines: Array = ["# Flaky Test Detector", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
