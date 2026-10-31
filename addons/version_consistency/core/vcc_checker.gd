## Version Consistency Checker - one version everywhere.
## Reads application/config/version from the project file (or --expected) and
## every version-like option of each export preset (version/name,
## application/version, application/short_version, application/file_version,
## application/product_version). Trailing ".0" components are ignored when
## comparing, so 1.2.0 and 1.2.0.0 match. Android version/code is reported
## but not compared.
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

const DEFAULTS := {"presets": "res://export_presets.cfg", "expected": ""}
const VERSION_KEYS: Array[String] = ["version/name", "application/version", "application/short_version", "application/file_version", "application/product_version"]


func run(input: String = "res://project.godot", options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    if not FileAccess.file_exists(input) or not FileAccess.file_exists(str(opts["presets"])):
        return _fail(input, "Project or presets file not found.", "Pass --project and --presets paths that exist.", "bad_input")
    return evaluate(FileAccess.get_file_as_string(input), FileAccess.get_file_as_string(str(opts["presets"])), opts, str(opts["presets"]))


func _norm(v: String) -> String:
    var parts := Array(v.strip_edges().split("."))
    while parts.size() > 1 and parts.back() == "0":
        parts.pop_back()
    return ".".join(parts)


func evaluate(project_text: String, presets_text: String, options: Dictionary = {}, presets_path: String = "") -> Dictionary:
    var opts := _opts(options)
    var proj := parse_ini(project_text)
    var expected := str(opts["expected"])
    if expected == "":
        expected = str(proj.get("application/config/version", {"value": ""})["value"]).trim_prefix("\"").trim_suffix("\"")
    var issues: Array = []
    if expected == "":
        issues.append(_issue("warning", "missing_version", "project", 0, "No application/config/version and no --expected.", "Set Project Settings > Application > Config > Version."))
        return _finish({"expected": "", "compared": 0}, issues)
    var ini := parse_ini(presets_text)
    var compared := 0
    var codes := {}
    for key in ini.keys():
        var k := str(key)
        if not k.begins_with("preset."):
            continue
        var idx := k.get_slice(".options/", 0) if k.contains(".options/") else ""
        if idx == "":
            continue
        var opt := k.get_slice(".options/", 1)
        var name := str(ini.get(idx + "/name", {"value": idx})["value"]).trim_prefix("\"").trim_suffix("\"")
        var value := str(ini[key]["value"]).trim_prefix("\"").trim_suffix("\"")
        if opt == "version/code":
            codes[name] = value
        if opt not in VERSION_KEYS:
            continue
        if value == "":
            issues.append(_issue("info", "missing_version", presets_path, ini[key]["line"], "Preset %s leaves %s empty." % [name, opt], "Set it to %s (empty may fall back to the project version or a default)." % expected))
            continue
        compared += 1
        if _norm(value) != _norm(expected):
            issues.append(_issue("warning", "version_mismatch", presets_path, ini[key]["line"], "Preset %s %s is %s, expected %s." % [name, opt, value, expected], "Update the preset (or the project version) so every build reports one version."))
    return _finish({"expected": expected, "compared": compared}, issues, {"android_version_codes": codes})


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
    var lines: Array = ["# Version Consistency Checker", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
