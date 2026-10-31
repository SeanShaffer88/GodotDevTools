## Handheld Readiness Checklist - small-screen and gamepad checks.
## Reads the project's viewport size, stretch mode and input map, then each UI
## scene's font size overrides and button focus modes. Font sizes are scaled
## from the project viewport height to the target screen height (assuming a
## stretch mode that scales the UI). The minimum is this tool's default, not a
## platform requirement; set it from your platform's current guidance.
extends RefCounted

const EXTS: Array[String] = ["tscn"]
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

const DEFAULTS := {"project": "res://project.godot", "target_height": 800, "min_text_px": 12.0}
const BUTTONS: Array[String] = ["Button", "CheckBox", "CheckButton", "OptionButton", "MenuButton", "LinkButton", "TextureButton", "ColorPickerButton"]


func run(input: String = "res://", options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    if not FileAccess.file_exists(str(opts["project"])):
        return _fail(str(opts["project"]), "Project file not found.", "Pass --project=<project.godot>.", "bad_input")
    if DirAccess.open(input) == null:
        return _fail(input, "Cannot open scan directory.", "Provide an existing readable project directory.")
    var paths: Array = []
    _walk(input, paths)
    paths.sort()
    var texts := {}
    for p in paths:
        texts[p] = FileAccess.get_file_as_string(p)
    opts["project_text"] = FileAccess.get_file_as_string(str(opts["project"]))
    return analyze(texts, opts)


func analyze(texts: Dictionary, options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    var ini := parse_ini(str(opts.get("project_text", "")))
    var project := str(opts["project"])
    var issues: Array = []
    var height := int(str(ini.get("display/window/size/viewport_height", {"value": "648"})["value"]))
    var stretch := str(ini.get("display/window/stretch/mode", {"value": "\"disabled\""})["value"]).trim_prefix("\"").trim_suffix("\"")
    if stretch == "disabled":
        issues.append(_issue("warning", "stretch_disabled", project, 0, "Stretch mode is disabled: the UI will not scale to a %d px tall screen." % opts["target_height"], "Set Display > Window > Stretch > Mode to canvas_items (and an aspect mode) so the UI scales."))
    var factor: float = float(opts["target_height"]) / max(1, height)
    for key in ini.keys():
        if not str(key).begins_with("input/") or str(key).begins_with("input/ui_"):
            continue
        var v := str(ini[key]["value"])
        if v.contains("InputEvent") and not v.contains("InputEventJoypad"):
            issues.append(_issue("warning", "no_gamepad_binding", project, ini[key]["line"], "Action %s has no gamepad binding." % str(key).trim_prefix("input/"), "Bind a joypad button or axis so the action works without a mouse and keyboard."))
    for path in texts.keys():
        if texts[path] == null:
            issues.append(_issue("error", "scan_error", str(path), 0, "Cannot read file.", "Check file permissions and retry."))
            continue
        var lines := str(texts[path]).split("\n")
        var node := ""
        var type := ""
        for index in range(lines.size()):
            var s := lines[index].strip_edges()
            if s.begins_with("[node "):
                node = s.get_slice("name=\"", 1).get_slice("\"", 0)
                type = s.get_slice("type=\"", 1).get_slice("\"", 0) if s.contains("type=\"") else ""
            elif s.begins_with("theme_override_font_sizes/font_size = "):
                var size := float(s.get_slice(" = ", 1))
                var scaled: float = size * factor
                if scaled < float(opts["min_text_px"]):
                    issues.append(_issue("warning", "small_text", str(path), index + 1, "%s: %d px text becomes %.1f px on a %d px tall screen." % [node, size, scaled, opts["target_height"]], "Use at least %d px at the project's %d px height." % [int(ceil(float(opts["min_text_px"]) / factor)), height]))
            elif s == "focus_mode = 0" and type in BUTTONS:
                issues.append(_issue("warning", "not_focusable", str(path), index + 1, "%s (%s) has focus_mode None and cannot be reached with a gamepad." % [node, type], "Set focus_mode to All and give it focus neighbours."))
    return _finish({"viewport_height": height, "scale_to_target": snappedf(factor, 0.001)}, issues)


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
    var lines: Array = ["# Handheld Readiness Checklist", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
