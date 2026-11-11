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
    var cache_path := str(opts.get("cache", ""))
    var cache_absolute := ProjectSettings.globalize_path(cache_path).simplify_path() if cache_path != "" else ""
    for p in paths:
        # A cache placed under the scan root must not become scan input itself.
        if cache_path != "" and ProjectSettings.globalize_path(str(p)).simplify_path() == cache_absolute:
            continue
        texts[p] = FileAccess.get_file_as_string(p)
    if cache_path != "":
        return _run_cached(texts, expect, cache_path)
    return analyze(texts, {"expect_list": expect})


## Incremental run: cache evidence per file, not just the first global match.
## This lets an unchanged file supply evidence if an earlier file is edited or
## removed. Changing the expectation list invalidates all cached matches.
func _run_cached(texts: Dictionary, expect: Array, cache_path: String) -> Dictionary:
    var config_hash := JSON.stringify(expect).sha256_text()
    var prior: Dictionary = {}
    if FileAccess.file_exists(cache_path):
        var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(cache_path))
        if typeof(parsed) == TYPE_DICTIONARY and int(parsed.get("version", 0)) == 2 and str(parsed.get("config_hash", "")) == config_hash and typeof(parsed.get("files", null)) == TYPE_DICTIONARY:
            prior = parsed["files"]
    var compiled := _compile_patterns(expect)
    var paths: Array = texts.keys()
    paths.sort()
    var entries := {}
    var matches := {}
    var cached_files := 0
    for path in paths:
        if texts[path] == null:
            continue
        var text := str(texts[path])
        var content_hash := text.sha256_text()
        var entry: Variant = prior.get(path, null)
        var per_file: Dictionary = {}
        if typeof(entry) == TYPE_DICTIONARY and str(entry.get("hash", "")) == content_hash and typeof(entry.get("matches", null)) == TYPE_DICTIONARY:
            per_file = entry["matches"]
            cached_files += 1
        else:
            per_file = _match_file(text, compiled)
        entries[path] = {"hash": content_hash, "matches": per_file}
        matches[path] = per_file
    if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(cache_path.get_base_dir())) != OK:
        return _fail(cache_path, "Cannot create cache directory.", "Choose a writable cache path.", "bad_input")
    var cache_file := FileAccess.open(cache_path, FileAccess.WRITE)
    if cache_file == null:
        return _fail(cache_path, "Cannot write cache.", "Choose a writable cache path.", "bad_input")
    cache_file.store_string(JSON.stringify({"version": 2, "config_hash": config_hash, "files": entries}, "  "))
    cache_file.close()
    return _assemble(expect, paths, matches, cached_files)


func analyze(texts: Dictionary, options: Dictionary = {}) -> Dictionary:
    var expect: Array = options.get("expect_list", DEFAULT_EXPECT)
    var compiled := _compile_patterns(expect)
    var paths: Array = texts.keys()
    paths.sort()
    var matches := {}
    for path in paths:
        if texts[path] != null:
            matches[path] = _match_file(str(texts[path]), compiled)
    return _assemble(expect, paths, matches)


## Compile each expression separately so capture groups/backreferences do not
## change when multiple patterns are supplied. Multiline keeps ^ and $ useful
## for searches through whole files.
func _compile_patterns(expect: Array) -> Dictionary:
    var compiled := {}
    for e in expect:
        var regexes: Array = []
        for pattern in e.get("patterns", []):
            var regex := RegEx.new()
            if regex.compile("(?im)" + str(pattern)) == OK:
                regexes.append(regex)
        compiled[str(e["id"])] = regexes
    return compiled


func _match_file(text: String, compiled: Dictionary) -> Dictionary:
    var matches := {}
    for id in compiled:
        var first := -1
        for regex in compiled[id]:
            var hit: RegExMatch = regex.search(text)
            if hit != null and (first < 0 or hit.get_start() < first):
                first = hit.get_start()
        if first >= 0:
            matches[id] = text.substr(0, first).count("\n") + 1
    return matches


func _assemble(expect: Array, paths: Array, matches: Dictionary, cached_files: int = -1) -> Dictionary:
    var evidence := {}
    var issues: Array = []
    for e in expect:
        var id := str(e["id"])
        for path in paths:
            var per_file: Dictionary = matches.get(path, {})
            if per_file.has(id):
                evidence[id] = "%s:%d" % [path, int(per_file[id])]
                break
        if not evidence.has(id):
            issues.append(_issue("warning", "option_not_found", "res://", 0, "No evidence of %s." % e.get("label", id), "Add the option to your settings menu, or adjust the patterns if it exists under another name."))
    var summary := {"expected": expect.size(), "found": evidence.size()}
    if cached_files >= 0:
        summary["cached_files"] = cached_files
    return _finish(summary, issues, {"evidence": evidence})


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
