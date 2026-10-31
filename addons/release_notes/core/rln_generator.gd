## Release Notes Generator - conventional-commit draft.
## Parses "type(scope)!: subject" lines. feat -> Added, fix -> Fixed,
## perf -> Performance, "!" or a BREAKING CHANGE mention -> Breaking; docs,
## refactor, test, chore, build, ci, style -> Other (hidden unless asked).
## Merge commits are skipped; anything else is listed as nonconventional so a
## human can place it. The draft is a starting point for a human edit.
extends RefCounted

const EXTS: Array[String] = ["txt"]
const DEFAULTS := {"version": "Unreleased", "include_other": false}
const SECTIONS := {"feat": "Added", "fix": "Fixed", "perf": "Performance"}

var _cc_re := RegEx.create_from_string("^([a-z]+)(\\(([^)]+)\\))?(!)?:\\s*(.+)$")


func run(input: String = "", options: Dictionary = {}) -> Dictionary:
    if not FileAccess.file_exists(input):
        return _fail(input, "Commits file not found.", "Write subjects with: git log --format=%s <from>..HEAD > commits.txt", "bad_input")
    return evaluate(FileAccess.get_file_as_string(input), options, input)


func evaluate(text: String, options: Dictionary = {}, path: String = "") -> Dictionary:
    var opts := _opts(options)
    var groups := {"Breaking": [], "Added": [], "Fixed": [], "Performance": [], "Other": [], "Unsorted": []}
    var issues: Array = []
    var lines := text.split("\n")
    for index in range(lines.size()):
        var s := lines[index].strip_edges()
        if s == "" or s.begins_with("Merge ") or s.begins_with("Revert \"Merge"):
            continue
        var m := _cc_re.search(s)
        if m == null:
            groups["Unsorted"].append(s)
            issues.append(_issue("info", "nonconventional_commit", path, index + 1, "Not a conventional commit: %s" % s, "Place it by hand, or write future subjects as type(scope): summary."))
            continue
        var entry := m.get_string(5)
        if m.get_string(3) != "":
            entry = "**%s:** %s" % [m.get_string(3), entry]
        var breaking := m.get_string(4) == "!" or s.contains("BREAKING CHANGE")
        if breaking:
            groups["Breaking"].append(entry)
            issues.append(_issue("warning", "breaking_change", path, index + 1, "Breaking change: %s" % m.get_string(5), "Call it out at the top of the notes with migration steps."))
            continue
        groups[SECTIONS.get(m.get_string(1), "Other")].append(entry)
    var out: Array = ["## [%s]" % opts["version"], ""]
    for section in ["Breaking", "Added", "Fixed", "Performance", "Other", "Unsorted"]:
        if groups[section].is_empty() or (section == "Other" and not opts["include_other"]):
            continue
        out.append("### " + section)
        out.append("")
        for e in groups[section]:
            out.append("- " + e)
        out.append("")
    var counts := {}
    for k in groups.keys():
        counts[k] = groups[k].size()
    return _finish(counts, issues, {"notes": "\n".join(out)})


func _markdown_extra(result: Dictionary) -> Array:
    return ["## Draft", "", str(result.get("notes", "")), ""]


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
    var lines: Array = ["# Release Notes Generator", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
