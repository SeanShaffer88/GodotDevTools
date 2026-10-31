## Android Permissions Reviewer - export preset permissions.
## Reads export_presets.cfg, finds presets with platform "Android", and lists
## permissions/<name>=true options plus permissions/custom_permissions. A
## built-in list of commonly sensitive permissions (camera, microphone,
## location, contacts, SMS, phone, sensors, storage and media) is flagged for
## human review. This is not a policy check; store policies change.
extends RefCounted

const EXTS: Array[String] = ["cfg"]
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

const DEFAULTS := {"justifications": ""}
const SENSITIVE: Array[String] = ["CAMERA", "RECORD_AUDIO", "ACCESS_FINE_LOCATION", "ACCESS_COARSE_LOCATION",
    "ACCESS_BACKGROUND_LOCATION", "READ_CONTACTS", "WRITE_CONTACTS", "GET_ACCOUNTS", "READ_SMS", "SEND_SMS", "RECEIVE_SMS",
    "CALL_PHONE", "READ_PHONE_STATE", "READ_CALL_LOG", "BODY_SENSORS", "READ_EXTERNAL_STORAGE", "WRITE_EXTERNAL_STORAGE",
    "READ_MEDIA_IMAGES", "READ_MEDIA_VIDEO", "READ_MEDIA_AUDIO", "READ_CALENDAR", "WRITE_CALENDAR", "ACTIVITY_RECOGNITION",
    "SYSTEM_ALERT_WINDOW", "REQUEST_INSTALL_PACKAGES", "MANAGE_EXTERNAL_STORAGE"]


func run(input: String = "res://export_presets.cfg", options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    if not FileAccess.file_exists(input):
        return _fail(input, "Export presets file not found.", "Pass --presets=<export_presets.cfg>.", "bad_input")
    var just: Variant = null
    if str(opts["justifications"]) != "":
        just = _read_json(str(opts["justifications"]))
        if typeof(just) != TYPE_DICTIONARY:
            return _fail(str(opts["justifications"]), "Justifications file missing or not a JSON object.", "Write {\"PERMISSION\": \"reason\"}.", "bad_input")
    return evaluate(FileAccess.get_file_as_string(input), just, input)


func permissions(text: String) -> Dictionary:
    var ini := parse_ini(text)
    var out := {}
    for key in ini.keys():
        var k := str(key)
        if k.begins_with("preset.") and k.ends_with("/platform") and str(ini[key]["value"]) == "\"Android\"":
            var idx := k.get_slice("/", 0)
            var name := str(ini.get(idx + "/name", {"value": idx})["value"]).trim_prefix("\"").trim_suffix("\"")
            var perms: Array = []
            for k2 in ini.keys():
                var s := str(k2)
                if s.begins_with(idx + ".options/permissions/"):
                    var p := s.trim_prefix(idx + ".options/permissions/")
                    if p == "custom_permissions":
                        var v := str(ini[k2]["value"])
                        for m in RegEx.create_from_string("\"([^\"]+)\"").search_all(v):
                            perms.append(m.get_string(1))
                    elif str(ini[k2]["value"]) == "true":
                        perms.append(p.to_upper())
            perms.sort()
            out[name] = perms
    return out


func evaluate(text: String, justifications: Variant = null, path: String = "") -> Dictionary:
    var presets := permissions(text)
    var issues: Array = []
    if presets.is_empty():
        issues.append(_issue("info", "no_android_preset", path, 0, "No Android export preset found.", "Nothing to review."))
    for name in presets.keys():
        for p in presets[name]:
            if p in SENSITIVE:
                issues.append(_issue("warning", "sensitive_permission", path, 0, "Preset %s requests %s." % [name, p], "Confirm the feature needs it, request it at runtime when used, and disclose it in the store listing and privacy policy."))
            if justifications != null and not justifications.has(p):
                issues.append(_issue("warning", "unjustified_permission", path, 0, "Preset %s requests %s with no written justification." % [name, p], "Add a reason to the justifications file or untick the permission."))
    return _finish({"android_presets": presets.size()}, issues, {"permissions": presets})


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
    var lines: Array = ["# Android Permissions Reviewer", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
