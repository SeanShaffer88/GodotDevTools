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
    var cache_path := str(opts.get("cache", ""))
    if cache_path != "":
        return _run_cached(texts, expect, cache_path)
    return analyze(texts, {"expect_list": expect})


## Incremental run: unchanged files (by content hash) reuse prior evidence.
## Cache format: {"hashes": {path: int}, "evidence": {id: "path:line"}}.
func _run_cached(texts: Dictionary, expect: Array, cache_path: String) -> Dictionary:
    var prior: Dictionary = {}
    if FileAccess.file_exists(cache_path):
        var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(cache_path))
        if typeof(parsed) == TYPE_DICTIONARY:
            prior = parsed
    var prior_hashes: Dictionary = prior.get("hashes", {})
    var prior_evidence: Dictionary = prior.get("evidence", {})
    var changed := {}
    var hashes := {}
    for p in texts.keys():
        var h := str(texts[p]).hash()
        hashes[p] = h
        if int(prior_hashes.get(p, -1)) != h:
            changed[p] = texts[p]
    var result: Dictionary = analyze(changed, {"expect_list": expect})
    var evidence: Dictionary = result.get("evidence", {}).duplicate()
    for id in prior_evidence.keys():
        if not evidence.has(id):
            var loc := str(prior_evidence[id])
            var file_path := loc.substr(0, loc.rfind(":")) if loc.contains(":") else loc
            if hashes.has(file_path) and int(prior_hashes.get(file_path, -1)) == int(hashes[file_path]):
                evidence[id] = loc
    var issues: Array = []
    for e in expect:
        if not evidence.has(e["id"]):
            issues.append(_issue("warning", "option_not_found", "res://", 0, "No evidence of %s." % e.get("label", e["id"]), "Add the option to your settings menu, or adjust the patterns if it exists under another name."))
    var cache_file := FileAccess.open(cache_path, FileAccess.WRITE)
    if cache_file != null:
        cache_file.store_string(JSON.stringify({"hashes": hashes, "evidence": evidence}, "  "))
        cache_file.close()
    return _finish({"expected": expect.size(), "found": evidence.size(), "cached_files": texts.size() - changed.size()}, issues, {"evidence": evidence})


func analyze(texts: Dictionary, options: Dictionary = {}) -> Dictionary:
    # Optimized: one combined regex per option, searched over whole files
    # (was: one regex per pattern, searched per line with a lambda).
    var expect: Array = options.get("expect_list", DEFAULT_EXPECT)
    var issues: Array = []
    var evidence := {}
    var paths: Array = texts.keys()
    paths.sort()
    for e in expect:
        var patterns: Array = e.get("patterns", [])
        if patterns.is_empty():
            continue
        var parts: Array = []
        for pat in patterns:
            parts.append("(" + str(pat) + ")")
        var regex := RegEx.create_from_string("(?i)" + "|".join(parts))
        if regex == null:
            continue
        for path in paths:
            if texts[path] == null or evidence.has(e["id"]):
                continue
            var text := str(texts[path])
            var match := regex.search(text)
            if match != null:
                var line := text.substr(0, match.get_start()).count("\n") + 1
                evidence[e["id"]] = "%s:%d" % [path, line]
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
