## GDScript Mutation Tester - test strength by mutation.
## Generates mutants of one script by changing one operator at a time
## (< <= > >= == != and or true false) outside strings and comments. Each
## mutant is written into a temporary project under user:// together with the
## unmodified test (same res:// paths) and run in a separate headless Godot
## process. A mutant is killed when the test exits non-zero, survives when it
## exits 0, and counts as hanging after the timeout. The real project files
## are only read, never written.
extends RefCounted

const EXTS: Array[String] = ["gd"]
const DEFAULTS := {"test": "", "max_mutants": 30, "timeout": 20.0, "work": "user://gdt_mutation"}
const SWAPS := {"<": ["<=", ">="], "<=": ["<", ">"], ">": [">=", "<="], ">=": [">", "<"], "==": ["!="], "!=": ["=="],
    "and": ["or"], "or": ["and"], "true": ["false"], "false": ["true"]}

var _op_re := RegEx.create_from_string("(?<![<>=!\\-])(<=|>=|==|!=|<|>)(?![=>])|\\b(and|or|true|false)\\b")


func run(input: String = "", options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    var test := str(opts["test"])
    if not FileAccess.file_exists(input) or not FileAccess.file_exists(test):
        return _fail(input, "Target or test script not found.", "Pass --target=<script> and --test=<test script>.", "bad_input")
    var source := FileAccess.get_file_as_string(input)
    var mutants := mutants(source).slice(0, int(opts["max_mutants"]))
    var work := ProjectSettings.globalize_path(str(opts["work"]))
    DirAccess.make_dir_recursive_absolute(work)
    var proj := FileAccess.open(work.path_join("project.godot"), FileAccess.WRITE)
    proj.store_string("config_version=5\n\n[application]\n\nconfig/name=\"gdt_mutation\"\n")
    proj.close()
    _write(work, test, FileAccess.get_file_as_string(test))
    _write(work, input, source)
    var baseline := _run_test(work, test, float(opts["timeout"]))
    if baseline != "pass":
        return _finish({"mutants": 0}, [_issue("error", "baseline_failed", test, 0, "The unmutated test does not pass in isolation (%s)." % baseline, "Make the test pass on its own first; it may depend on files outside the target and test.")])
    var outcomes: Array = []
    for m in mutants:
        _write(work, input, m["source"])
        m["outcome"] = _run_test(work, test, float(opts["timeout"]))
        m.erase("source")
        outcomes.append(m)
    _write(work, input, source)
    return evaluate(outcomes, input)


## Every single-operator mutant: [{line, from, to, source}].
func mutants(source: String) -> Array:
    var out: Array = []
    var lines := source.split("\n")
    for index in range(lines.size()):
        var line: String = lines[index]
        var stripped := line.strip_edges()
        if stripped.begins_with("#") or stripped.begins_with("##"):
            continue
        var code_end := _code_end(line)
        for m in _op_re.search_all(line):
            if m.get_start() >= code_end or _in_string(line, m.get_start()):
                continue
            var op := m.get_string()
            for to in SWAPS.get(op, []):
                var changed: String = line.substr(0, m.get_start()) + str(to) + line.substr(m.get_end())
                var copy := lines.duplicate()
                copy[index] = changed
                out.append({"line": index + 1, "from": op, "to": to, "source": "\n".join(copy)})
    return out


func _code_end(line: String) -> int:
    var in_str := false
    for i in range(line.length()):
        if line[i] == "\"":
            in_str = not in_str
        elif line[i] == "#" and not in_str:
            return i
    return line.length()


func _in_string(line: String, pos: int) -> bool:
    return line.substr(0, pos).count("\"") % 2 == 1


func _write(work: String, res_path: String, text: String) -> void:
    var target := work.path_join(res_path.trim_prefix("res://"))
    DirAccess.make_dir_recursive_absolute(target.get_base_dir())
    var f := FileAccess.open(target, FileAccess.WRITE)
    f.store_string(text)
    f.close()


## "pass", "fail" or "timeout" for one run of the test in the work project.
func _run_test(work: String, test: String, timeout: float) -> String:
    var pid := OS.create_process(OS.get_executable_path(), ["--headless", "--path", work, "--script", test])
    if pid <= 0:
        return "fail"
    var deadline := Time.get_ticks_msec() + int(timeout * 1000.0)
    while OS.is_process_running(pid):
        if Time.get_ticks_msec() > deadline:
            OS.kill(pid)
            return "timeout"
        OS.delay_msec(20)
    return "pass" if OS.get_process_exit_code(pid) == 0 else "fail"


func evaluate(outcomes: Array, path: String = "") -> Dictionary:
    var issues: Array = []
    var killed := 0
    for m in outcomes:
        match m["outcome"]:
            "pass":
                issues.append(_issue("warning", "survived_mutant", path, m["line"], "Changing `%s` to `%s` on line %d is not caught by the test." % [m["from"], m["to"], m["line"]], "Add a test case that distinguishes the two (often the exact boundary value)."))
            "timeout":
                issues.append(_issue("info", "timeout_mutant", path, m["line"], "`%s` -> `%s` made the test hang (counted as killed)." % [m["from"], m["to"]], "Usually a loop condition; fine unless the original code can hang too."))
                killed += 1
            _:
                killed += 1
    var score := 0.0 if outcomes.is_empty() else float(killed) / outcomes.size()
    return _finish({"mutants": outcomes.size(), "killed": killed, "score": snappedf(score, 0.001)}, issues)


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
    var lines: Array = ["# GDScript Mutation Tester", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
