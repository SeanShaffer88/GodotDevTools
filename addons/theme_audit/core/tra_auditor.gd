## Theme Resource Auditor - theme consistency.
## Counts theme_override_* properties per scene, collects every font size
## (overrides and Theme resources), and lists type variations defined in
## Theme resources that no scene node selects with theme_type_variation.
## Per-node overrides bypass the theme; a few are normal, many mean the theme
## is not doing its job.
extends RefCounted

const EXTS: Array[String] = ["tscn", "tres"]
const DEFAULTS := {"max_overrides": 20, "max_font_sizes": 6}

var _variation_re := RegEx.create_from_string("^([A-Za-z_][A-Za-z0-9_]*)/base_type\\s*=")
var _size_re := RegEx.create_from_string("font_sizes?/font_size\\s*=\\s*(\\d+)|^default_font_size\\s*=\\s*(\\d+)")


func analyze(texts: Dictionary, options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    var issues: Array = []
    var sizes := {}
    var variations := {}
    var used := {}
    for path in texts.keys():
        if texts[path] == null:
            issues.append(_issue("error", "scan_error", str(path), 0, "Cannot read file.", "Check file permissions and retry."))
            continue
        var text := str(texts[path])
        var overrides := 0
        var lines := text.split("\n")
        for index in range(lines.size()):
            var s := lines[index].strip_edges()
            if s.begins_with("theme_override_"):
                overrides += 1
            var sm := _size_re.search(s)
            if sm != null:
                var size := int(sm.get_string(1) if sm.get_string(1) != "" else sm.get_string(2))
                if not sizes.has(size):
                    sizes[size] = "%s:%d" % [path, index + 1]
            var vm := _variation_re.search(s)
            if vm != null and text.begins_with("[gd_resource type=\"Theme\""):
                variations[vm.get_string(1)] = [str(path), index + 1]
            if s.begins_with("theme_type_variation = "):
                used[s.trim_prefix("theme_type_variation = ").trim_prefix("&").trim_prefix("\"").trim_suffix("\"")] = true
        if overrides > int(opts["max_overrides"]):
            issues.append(_issue("warning", "override_sprawl", str(path), 0, "%d per-node theme overrides (limit %d)." % [overrides, opts["max_overrides"]], "Move repeated overrides into the Theme as type variations."))
    var scale: Array = sizes.keys()
    scale.sort()
    if scale.size() > int(opts["max_font_sizes"]):
        issues.append(_issue("warning", "font_size_sprawl", "res://", 0, "%d distinct font sizes: %s." % [scale.size(), ", ".join(scale.map(func(v): return str(v)))], "Pick a type scale (e.g. 12/16/20/28/40) and map every size onto it."))
    for i in range(1, scale.size()):
        if int(scale[i]) - int(scale[i - 1]) <= 1:
            var where: String = sizes[scale[i]]
            issues.append(_issue("info", "near_duplicate_sizes", where.get_slice(":", 0) + ":" + where.get_slice(":", 1), int(where.get_slice(":", 2)), "Font sizes %d and %d differ by 1 px." % [scale[i - 1], scale[i]], "Merge them into one size."))
    for v in variations.keys():
        if not used.has(v):
            issues.append(_issue("info", "unused_variation", variations[v][0], variations[v][1], "Theme type variation %s is not used by any scanned scene." % v, "Remove it, or set theme_type_variation where it was meant to apply."))
    return _finish({"files": texts.size(), "font_sizes": scale.size(), "variations": variations.size()}, issues, {"font_sizes": scale})

func run(input: String = "res://", options: Dictionary = {}) -> Dictionary:
    if DirAccess.open(input) == null:
        return _fail(input, "Cannot open scan directory.", "Provide an existing readable project directory.")
    var paths: Array = []
    _walk(input, paths)
    paths.sort()
    var texts := {}
    for path in paths:
        var file := FileAccess.open(path, FileAccess.READ)
        texts[path] = null if file == null else file.get_as_text()
    return analyze(texts, options)


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
    var lines: Array = ["# Theme Resource Auditor", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
