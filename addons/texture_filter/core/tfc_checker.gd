## Texture Filter Consistency Checker - pixel-art settings.
## Pixel art wants nearest filtering, no mipmaps and lossless storage.
## Textures are classed as pixel art by a path pattern; their .import
## parameters are checked, and the project's default canvas texture filter
## (rendering/textures/canvas_textures/default_texture_filter, Linear when
## unset) is reported when pixel art exists.
extends RefCounted

const EXTS: Array[String] = ["import"]
const DEFAULTS := {"pixel_pattern": "/pixel", "project": "res://project.godot"}
const LOSSY := {1: "Lossy", 2: "VRAM Compressed", 4: "Basis Universal"}


func run(input: String = "res://", options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    if DirAccess.open(input) == null:
        return _fail(input, "Cannot open scan directory.", "Provide an existing readable project directory.")
    var paths: Array = []
    _walk(input, paths)
    paths.sort()
    var texts := {}
    for p in paths:
        texts[p] = FileAccess.get_file_as_string(p)
    var project := str(opts["project"])
    opts["project_text"] = FileAccess.get_file_as_string(project) if FileAccess.file_exists(project) else ""
    return analyze(texts, opts)


func analyze(texts: Dictionary, options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    var issues: Array = []
    var pixel := 0
    for path in texts.keys():
        if texts[path] == null:
            issues.append(_issue("error", "scan_error", str(path), 0, "Cannot read file.", "Check file permissions and retry."))
            continue
        var text := str(texts[path])
        if not text.contains("importer=\"texture\""):
            continue
        var src := str(path).trim_suffix(".import")
        if not src.to_lower().contains(str(opts["pixel_pattern"])):
            continue
        pixel += 1
        var lines := text.split("\n")
        for index in range(lines.size()):
            var s := lines[index].strip_edges()
            if s == "mipmaps/generate=true":
                issues.append(_issue("warning", "pixel_mipmaps", str(path), index + 1, "Pixel-art texture generates mipmaps.", "Disable Mipmaps > Generate in the Import dock; mipmaps blur pixel art when scaled down."))
            elif s.begins_with("compress/mode=") and LOSSY.has(int(s.get_slice("=", 1))):
                issues.append(_issue("warning", "pixel_lossy", str(path), index + 1, "Pixel-art texture uses %s compression." % LOSSY[int(s.get_slice("=", 1))], "Use Lossless (or VRAM Uncompressed) so hard pixel edges survive."))
    if pixel > 0:
        var filter := 1
        for line in str(opts.get("project_text", "")).split("\n"):
            if line.begins_with("textures/canvas_textures/default_texture_filter="):
                filter = int(line.get_slice("=", 1))
        if filter != 0:
            issues.append(_issue("info", "filter_default_linear", str(opts["project"]), 0, "%d pixel-art textures, but the default canvas texture filter is %s." % [pixel, ["Nearest", "Linear", "Nearest Mipmap", "Linear Mipmap"][clampi(filter, 0, 3)]], "Set Rendering > Textures > Canvas Textures > Default Texture Filter to Nearest, or set texture_filter on the nodes that draw pixel art."))
    return _finish({"pixel_textures": pixel}, issues)


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
    var lines: Array = ["# Texture Filter Consistency Checker", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
