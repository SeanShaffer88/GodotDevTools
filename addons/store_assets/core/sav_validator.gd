## Store Asset Validator - profile-driven image checks.
## The profile lists assets as a single file with width/height (or "sizes"),
## or a folder of images with allowed sizes and a count range. Image sizes are
## read from PNG IHDR and JPEG SOF headers. Store requirements change; the
## profile is the user's own copy of them, and this tool makes no claim about
## any store's current rules.
extends RefCounted

const EXTS: Array[String] = ["png", "jpg", "jpeg"]
const DEFAULTS := {}


func run(input: String = "", options: Dictionary = {}) -> Dictionary:
    var profile: Variant = _read_json(input)
    if typeof(profile) != TYPE_DICTIONARY or typeof(profile.get("assets")) != TYPE_ARRAY:
        return _fail(input, "Profile missing or without an assets array.", "See the README for the profile format.", "bad_profile")
    var sizes := {}
    for a in profile["assets"]:
        if typeof(a) != TYPE_DICTIONARY:
            continue
        if a.has("path") and FileAccess.file_exists(str(a["path"])):
            sizes[str(a["path"])] = image_size(FileAccess.get_file_as_bytes(str(a["path"])))
        elif a.has("folder") and DirAccess.open(str(a["folder"])) != null:
            var files: Array = []
            _walk(str(a["folder"]), files)
            for f in files:
                sizes[str(f)] = image_size(FileAccess.get_file_as_bytes(f))
    return evaluate(profile, sizes, input)


## [width, height] from PNG or JPEG bytes, or [] when unknown.
func image_size(b: PackedByteArray) -> Array:
    if b.size() >= 24 and b[0] == 0x89 and b.slice(1, 4).get_string_from_ascii() == "PNG":
        return [_be(b, 16, 4), _be(b, 20, 4)]
    if b.size() >= 4 and b[0] == 0xFF and b[1] == 0xD8:
        var i := 2
        while i + 9 < b.size():
            if b[i] != 0xFF:
                i += 1
                continue
            var marker := b[i + 1]
            if marker in [0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7, 0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF]:
                return [_be(b, i + 7, 2), _be(b, i + 5, 2)]
            if marker == 0xD8 or marker == 0x01 or (marker >= 0xD0 and marker <= 0xD7):
                i += 2
                continue
            i += 2 + _be(b, i + 2, 2)
    return []


func _be(b: PackedByteArray, o: int, n: int) -> int:
    var v := 0
    for k in range(n):
        v = (v << 8) | b[o + k]
    return v


func _allowed(a: Dictionary) -> Array:
    if a.has("sizes"):
        return a["sizes"].map(func(s): return [int(s[0]), int(s[1])])
    return [[int(a.get("width", 0)), int(a.get("height", 0))]]


func evaluate(profile: Dictionary, sizes: Dictionary, path: String = "") -> Dictionary:
    var issues: Array = []
    var checked := 0
    for a in profile["assets"]:
        if typeof(a) != TYPE_DICTIONARY or not (a.has("path") or a.has("folder")):
            return _fail(path, "Each asset needs a path or folder: %s" % str(a), "Fix the profile entry.", "bad_profile")
        var id := str(a.get("id", a.get("path", a.get("folder"))))
        var allowed := _allowed(a)
        var files: Array = []
        if a.has("path"):
            if not sizes.has(str(a["path"])):
                issues.append(_issue("error", "missing_asset", str(a["path"]), 0, "%s is missing." % id, "Create the file at this path."))
                continue
            files = [str(a["path"])]
        else:
            var prefix := str(a["folder"]).trim_suffix("/") + "/"
            for p in sizes.keys():
                if str(p).begins_with(prefix):
                    files.append(str(p))
            files.sort()
            var lo := int(a.get("min_count", 0))
            var hi := int(a.get("max_count", 1 << 30))
            if files.size() < lo or files.size() > hi:
                issues.append(_issue("warning", "count_out_of_range", str(a["folder"]), 0, "%s: %d images, profile wants %d-%d." % [id, files.size(), lo, hi], "Add or remove images."))
        for f in files:
            checked += 1
            var s: Array = sizes[f]
            if s.is_empty():
                issues.append(_issue("warning", "wrong_size", f, 0, "%s: cannot read the image size (PNG/JPEG only)." % id, "Export as PNG or JPEG."))
            elif not allowed.has([int(s[0]), int(s[1])]):
                issues.append(_issue("warning", "wrong_size", f, 0, "%s is %dx%d; allowed %s." % [id, s[0], s[1], ", ".join(allowed.map(func(x): return "%dx%d" % [x[0], x[1]]))], "Re-export at an allowed size."))
    return _finish({"images_checked": checked}, issues)


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
    var lines: Array = ["# Store Asset Validator", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
