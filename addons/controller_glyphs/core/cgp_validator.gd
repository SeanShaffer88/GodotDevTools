## Controller Glyph and Prompt Validator - prompts, bindings, glyphs.
## Prompt tokens (default "[action:jump]") are collected from text files.
## Each action must exist in the project's InputMap; for each device folder
## under the glyph root (folder names are device ids: keyboard, mouse,
## xbox, playstation, switch, steamdeck...), the action must have a binding
## of that device family (keyboard/mouse vs joypad events) and a glyph image
## named <action>.png/.svg/.webp.
extends RefCounted

const EXTS: Array[String] = ["csv", "po", "gd", "tscn", "json"]
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

const DEFAULTS := {"glyphs": "", "project": "res://project.godot", "token": "\\[action:([a-z0-9_]+)\\]"}
const KEYBOARD_DEVICES: Array[String] = ["keyboard", "mouse", "kbm", "pc"]


func run(input: String = "", options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    if DirAccess.open(input) == null:
        return _fail(input, "Cannot open scan directory.", "Provide an existing readable folder.")
    if not FileAccess.file_exists(str(opts["project"])):
        return _fail(str(opts["project"]), "Project file not found.", "Pass --project=<project.godot>.", "bad_input")
    var paths: Array = []
    _walk(input, paths)
    paths.sort()
    var texts := {}
    for p in paths:
        texts[p] = FileAccess.get_file_as_string(p)
    var root := str(opts["glyphs"]) if str(opts["glyphs"]) != "" else input
    var glyphs := {}
    var dir := DirAccess.open(root)
    if dir != null:
        for device in dir.get_directories():
            glyphs[device] = {}
            for f in DirAccess.get_files_at(root.path_join(device)):
                if f.get_extension().to_lower() in ["png", "svg", "webp"]:
                    glyphs[device][f.get_basename()] = true
    var o: Dictionary = opts.duplicate()
    o["glyph_index"] = glyphs
    o["project_text"] = FileAccess.get_file_as_string(str(opts["project"]))
    return analyze(texts, o)


## {action: {"keyboard": bool, "joypad": bool}} from a project file's [input] section.
func bindings(project_text: String) -> Dictionary:
    var out := {}
    var ini := parse_ini(project_text)
    for key in ini.keys():
        if str(key).begins_with("input/"):
            var v := str(ini[key]["value"])
            out[str(key).trim_prefix("input/")] = {"keyboard": v.contains("InputEventKey") or v.contains("InputEventMouse"), "joypad": v.contains("InputEventJoypad")}
    return out


func analyze(texts: Dictionary, options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    var glyphs: Dictionary = options.get("glyph_index", {})
    var binds := bindings(str(options.get("project_text", "")))
    var re := RegEx.create_from_string(str(opts["token"]))
    var issues: Array = []
    var used := {}
    for path in texts.keys():
        if texts[path] == null:
            continue
        var lines := str(texts[path]).split("\n")
        for index in range(lines.size()):
            for m in re.search_all(lines[index]):
                if not used.has(m.get_string(1)):
                    used[m.get_string(1)] = "%s:%d" % [path, index + 1]
    var actions: Array = used.keys()
    actions.sort()
    for a in actions:
        var where: String = used[a]
        var file := where.substr(0, where.rfind(":"))
        var line := int(where.substr(where.rfind(":") + 1))
        if not binds.has(a) and not str(a).begins_with("ui_"):
            issues.append(_issue("error", "unknown_action", file, line, "Prompt references action '%s', which the InputMap does not define." % a, "Fix the token or add the action."))
            continue
        var devices: Array = glyphs.keys()
        devices.sort()
        for device in devices:
            var family := "keyboard" if str(device).to_lower() in KEYBOARD_DEVICES else "joypad"
            var bound: bool = binds.get(a, {"keyboard": true, "joypad": true})[family]
            if not bound:
                issues.append(_issue("warning", "unbound_for_device", file, line, "'%s' is prompted but has no %s binding, so %s players cannot press it." % [a, family, device], "Add a %s binding, or hide the prompt on that device." % family))
            elif not glyphs[device].has(a):
                issues.append(_issue("warning", "missing_glyph", file, line, "No %s glyph for '%s' (expected %s/%s.png)." % [device, a, device, a], "Add the glyph image so the prompt does not fall back to text."))
    return _finish({"actions_prompted": actions.size(), "devices": glyphs.size()}, issues)


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
    var lines: Array = ["# Controller Glyph and Prompt Validator", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
