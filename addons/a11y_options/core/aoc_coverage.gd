## Accessibility Options Coverage - option evidence search.
## Each expected option has keyword patterns (regular expressions). Project
## scripts, scenes and data files are searched; an option with no match is
## reported. A match is evidence the option probably exists, not proof that
## it works - test each option with players who need it.
extends RefCounted

const EXTS: Array[String] = ["gd", "tscn", "tres", "json", "cfg", "csv"]
const DEFAULT_EXPECT := [
    {"id": "subtitles", "label": "Subtitles / captions", "patterns": ["subtitle", "caption"]},
    {"id": "remapping", "label": "Control remapping", "patterns": ["remap", "rebind", "key_?bind"]},
    {"id": "text_size", "label": "Text size / UI scale", "patterns": ["text_?(size|scale)", "font_?scale", "ui_?scale"]},
    {"id": "colorblind", "label": "Colour-blind modes", "patterns": ["colou?r_?blind", "daltoni", "protanop", "deuteranop", "tritanop"]},
    {"id": "reduce_motion", "label": "Reduced motion / screen shake", "patterns": ["reduce_?motion", "screen_?shake", "camera_?shake", "motion_?blur"]},
    {"id": "mono_audio", "label": "Mono audio", "patterns": ["mono_?audio", "audio_?mono", "downmix"]},
    {"id": "hold_toggle", "label": "Hold-to-toggle inputs", "patterns": ["hold_?to_?toggle", "toggle_?(sprint|aim|crouch|hold)"]},
]
const DEFAULTS := {"expect": ""}


func run(input: String = "res://", options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    var expect: Variant = DEFAULT_EXPECT
    if str(opts["expect"]) != "":
        expect = _read_json(str(opts["expect"]))
        if typeof(expect) != TYPE_ARRAY:
            return _fail(str(opts["expect"]), "Expected-options file missing or not a JSON array.", "See the README for the format.", "bad_input")
    if DirAccess.open(input) == null:
        return _fail(input, "Cannot open scan directory.", "Provide an existing readable project directory.")
    var paths: Array = []
    _walk(input, paths)
    paths.sort()
    var texts := {}
    for p in paths:
        texts[p] = FileAccess.get_file_as_string(p)
    return analyze(texts, {"expect_list": expect})


func analyze(texts: Dictionary, options: Dictionary = {}) -> Dictionary:
    var expect: Array = options.get("expect_list", DEFAULT_EXPECT)
    var issues: Array = []
    var evidence := {}
    var paths: Array = texts.keys()
    paths.sort()
    for e in expect:
        var res: Array = e.get("patterns", []).map(func(p): return RegEx.create_from_string("(?i)" + str(p)))
        for path in paths:
            if texts[path] == null or evidence.has(e["id"]):
                continue
            var lines := str(texts[path]).split("\n")
            for index in range(lines.size()):
                if res.any(func(r): return r != null and r.search(lines[index]) != null):
                    evidence[e["id"]] = "%s:%d" % [path, index + 1]
                    break
        if not evidence.has(e["id"]):
            issues.append(_issue("warning", "option_not_found", "res://", 0, "No evidence of %s." % e.get("label", e["id"]), "Add the option to your settings menu, or adjust the patterns if it exists under another name."))
    return _finish({"expected": expect.size(), "found": evidence.size()}, issues, {"evidence": evidence})


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
    var lines: Array = ["# Accessibility Options Coverage", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
