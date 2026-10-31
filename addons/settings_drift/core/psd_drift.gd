## Project Settings Drift Report - settings diff.
## Parses two Godot ConfigFile texts (the project file and a baseline copy),
## flattens them to section/key pairs, and reports keys added, removed or
## changed. Ignore prefixes skip settings expected to differ. Read-only.
extends RefCounted

const EXTS: Array[String] = ["godot", "cfg"]
## Parse Godot ConfigFile text (project.godot style) into {"section/key": value-text}.
## Multi-line values (dictionaries, arrays) are joined until brackets balance.
func parse_ini(text: String) -> Dictionary:
    var out := {}
    var section := ""
    var pending_key := ""
    var pending := ""
    var lines := text.split("\n")
    for index in range(lines.size()):
        var line: String = lines[index]
        if pending_key != "":
            pending += "\n" + line
            if _balanced(pending):
                out[pending_key] = {"value": pending.strip_edges(), "line": out[pending_key]["line"]}
                pending_key = ""
            continue
        var s := line.strip_edges()
        if s == "" or s.begins_with(";") or s.begins_with("#"):
            continue
        if s.begins_with("[") and s.ends_with("]"):
            section = s.substr(1, s.length() - 2)
            continue
        var eq := s.find("=")
        if eq < 0:
            continue
        var key := s.substr(0, eq).strip_edges()
        var full := key if section == "" else section + "/" + key
        var value := s.substr(eq + 1).strip_edges()
        out[full] = {"value": value, "line": index + 1}
        if not _balanced(value):
            pending_key = full
            pending = value
    return out


func _balanced(v: String) -> bool:
    var depth := 0
    var in_str := false
    var prev := ""
    for c in v:
        if c == "\"" and prev != "\\":
            in_str = not in_str
        elif not in_str:
            if c in ["{", "["]:
                depth += 1
            elif c in ["}", "]"]:
                depth -= 1
        prev = c
    return depth <= 0

const DEFAULTS := {"baseline": "res://project_baseline.godot", "ignore": []}


func run(input: String = "res://project.godot", options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    for p in [input, str(opts["baseline"])]:
        if not FileAccess.file_exists(p):
            return _fail(p, "File not found.", "Pass --project and --baseline paths that exist; create the baseline by copying an approved project.godot.", "bad_input")
    return analyze({input: FileAccess.get_file_as_string(input), str(opts["baseline"]): FileAccess.get_file_as_string(str(opts["baseline"]))}, {"project": input, "baseline": opts["baseline"], "ignore": opts["ignore"]})


func analyze(texts: Dictionary, options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    var project: String = opts.get("project", "res://project.godot")
    var base_path: String = opts["baseline"]
    if texts.get(project) == null or texts.get(base_path) == null:
        return _fail(project, "Project or baseline text missing.", "Pass both files.", "bad_input")
    var cur := parse_ini(str(texts[project]))
    var base := parse_ini(str(texts[base_path]))
    var issues: Array = []
    var keys := {}
    for k in cur.keys():
        keys[k] = true
    for k in base.keys():
        keys[k] = true
    var changed := 0
    for k in keys.keys():
        var skip := false
        for prefix in opts["ignore"]:
            if str(k).begins_with(str(prefix)):
                skip = true
        if skip:
            continue
        if cur.has(k) and not base.has(k):
            issues.append(_issue("info", "setting_added", project, cur[k]["line"], "%s = %s is not in the baseline." % [k, _short(cur[k]["value"])], "If intended, refresh the baseline; otherwise remove the setting."))
        elif base.has(k) and not cur.has(k):
            issues.append(_issue("warning", "setting_removed", project, 0, "%s (baseline %s) was removed." % [k, _short(base[k]["value"])], "Restore it, or refresh the baseline if the removal is intended."))
        elif str(cur[k]["value"]) != str(base[k]["value"]):
            changed += 1
            issues.append(_issue("warning", "setting_changed", project, cur[k]["line"], "%s: %s -> %s." % [k, _short(base[k]["value"]), _short(cur[k]["value"])], "Confirm the change is intended, then refresh the baseline."))
    return _finish({"project_keys": cur.size(), "baseline_keys": base.size(), "changed": changed}, issues)


func _short(v: Variant) -> String:
    var s := str(v).replace("\n", " ")
    return s if s.length() <= 80 else s.substr(0, 77) + "..."


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
    var lines: Array = ["# Project Settings Drift Report", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
