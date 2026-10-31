## Settings File Validator - schema validation.
## Schema: {"fields": {"section/key": {"type": int|float|bool|string,
## "min", "max", "enum", "default"}}}. Each sample settings file (Godot
## ConfigFile text or a JSON object, nested one level as section/key) is
## checked. Missing keys are informational because the default applies.
## Use real files collected from testers, including old versions.
extends RefCounted

const EXTS: Array[String] = ["cfg", "json"]
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

const DEFAULTS := {"schema": ""}


func run(input: String = "", options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    var schema_path := str(opts["schema"]) if str(opts["schema"]) != "" else input.path_join("schema.json")
    var schema: Variant = _read_json(schema_path)
    if typeof(schema) != TYPE_DICTIONARY or typeof(schema.get("fields")) != TYPE_DICTIONARY:
        return _fail(schema_path, "Schema missing or without a fields object.", "See the README for the schema format.", "bad_schema")
    if DirAccess.open(input) == null:
        return _fail(input, "Cannot open settings folder.", "Pass --dir=<folder of sample settings>.")
    var paths: Array = []
    _walk(input, paths)
    var files := {}
    for p in paths:
        if str(p) == schema_path:
            continue
        files[p] = FileAccess.get_file_as_string(p)
    return evaluate(files, schema["fields"])


func flatten(path: String, text: String) -> Variant:
    if path.get_extension() == "json":
        var data: Variant = JSON.parse_string(text)
        if typeof(data) != TYPE_DICTIONARY:
            return null
        var out := {}
        for k in data.keys():
            if typeof(data[k]) == TYPE_DICTIONARY:
                for k2 in data[k].keys():
                    out["%s/%s" % [k, k2]] = data[k][k2]
            else:
                out[str(k)] = data[k]
        return out
    var ini := parse_ini(text)
    var values := {}
    for k in ini.keys():
        values[k] = str_to_var(str(ini[k]["value"]))
    return values


func evaluate(files: Dictionary, fields: Dictionary) -> Dictionary:
    var issues: Array = []
    var names: Array = files.keys()
    names.sort()
    for path in names:
        var values: Variant = flatten(str(path), str(files[path]))
        if values == null:
            issues.append(_issue("error", "bad_input", str(path), 0, "Not a readable settings file.", "Settings must be ConfigFile text or a JSON object."))
            continue
        for key in values.keys():
            if not fields.has(key):
                issues.append(_issue("info", "unknown_key", str(path), 0, "%s is not in the schema." % key, "Migrate or drop old keys on load; add new ones to the schema."))
                continue
            var spec: Dictionary = fields[key]
            var v: Variant = values[key]
            var want := str(spec.get("type", "string"))
            var ok_type := (want == "bool" and typeof(v) == TYPE_BOOL) or (want == "int" and typeof(v) == TYPE_INT) or (want == "float" and typeof(v) in [TYPE_INT, TYPE_FLOAT]) or (want == "string" and typeof(v) in [TYPE_STRING, TYPE_STRING_NAME])
            if not ok_type:
                issues.append(_issue("warning", "wrong_type", str(path), 0, "%s is %s, schema says %s." % [key, type_string(typeof(v)), want], "Coerce or reset to the default (%s) when loading." % str(spec.get("default"))))
                continue
            if want in ["int", "float"] and ((spec.has("min") and float(v) < float(spec["min"])) or (spec.has("max") and float(v) > float(spec["max"]))):
                issues.append(_issue("warning", "out_of_range", str(path), 0, "%s = %s is outside %s..%s." % [key, v, spec.get("min", "-inf"), spec.get("max", "inf")], "Clamp it when loading."))
            if spec.has("enum") and v not in spec["enum"]:
                issues.append(_issue("warning", "invalid_enum", str(path), 0, "%s = %s is not one of %s." % [key, v, ", ".join(spec["enum"].map(func(e): return str(e)))], "Fall back to the default (%s) when loading." % str(spec.get("default"))))
        for key in fields.keys():
            if not values.has(key):
                issues.append(_issue("info", "missing_key", str(path), 0, "%s is missing; the default %s applies." % [key, fields[key].get("default")], "Nothing to do if the loader applies defaults."))
    return _finish({"files": names.size(), "fields": fields.size()}, issues)


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
    var lines: Array = ["# Settings File Validator", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
