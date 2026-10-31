## Texture Atlas Packing Planner - shelf packing estimate.
## Sorts sprites by height and fills shelves left to right on square pages,
## with padding between sprites. Reports pages needed, the share of page area
## left empty, and sprites larger than a page. A planning estimate: real
## packers (MaxRects, rotation, trimming) usually do better.
extends RefCounted

const EXTS: Array[String] = ["png"]
const DEFAULTS := {"page_size": 2048, "padding": 2, "max_pages": 4, "max_waste": 0.5}


func run(input: String = "", options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    var sprites: Array = []
    if input.get_extension() == "json":
        var data: Variant = _read_json(input)
        if typeof(data) != TYPE_DICTIONARY or typeof(data.get("sprites")) != TYPE_ARRAY:
            return _fail(input, "Sizes file missing or without a sprites array.", "See the README for the format.", "bad_input")
        sprites = data["sprites"]
        if data.has("page_size") and not options.has("page_size"):
            opts["page_size"] = int(data["page_size"])
        if data.has("padding") and not options.has("padding"):
            opts["padding"] = int(data["padding"])
    elif DirAccess.open(input) != null:
        var paths: Array = []
        _walk(input, paths)
        paths.sort()
        for p in paths:
            var f := FileAccess.open(p, FileAccess.READ)
            if f == null:
                continue
            var head := f.get_buffer(24)
            if head.size() == 24 and head.slice(1, 4).get_string_from_ascii() == "PNG":
                sprites.append({"name": str(p), "w": _be32(head, 16), "h": _be32(head, 20)})
    else:
        return _fail(input, "Input is neither a JSON sizes file nor a folder.", "Pass --input=<sizes.json or folder of PNGs>.", "bad_input")
    return pack(sprites, opts)


func _be32(b: PackedByteArray, o: int) -> int:
    return (b[o] << 24) | (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3]


func pack(sprites: Array, opts: Dictionary) -> Dictionary:
    var size := int(opts["page_size"])
    var pad := int(opts["padding"])
    var issues: Array = []
    var items: Array = []
    for s in sprites:
        var w := int(s.get("w", 0))
        var h := int(s.get("h", 0))
        if w > size or h > size:
            issues.append(_issue("warning", "sprite_too_big", str(s.get("name", "?")), 0, "%dx%d does not fit a %d page." % [w, h, size], "Keep it as its own texture or downscale it."))
        elif w > 0 and h > 0:
            items.append({"name": str(s.get("name", "?")), "w": w, "h": h})
    items.sort_custom(func(a, b): return a["h"] > b["h"] if a["h"] != b["h"] else (a["w"] > b["w"] if a["w"] != b["w"] else a["name"] < b["name"]))
    var pages := 0
    var x := 0
    var y := 0
    var shelf := 0
    var used := 0
    var placements: Array = []
    for it in items:
        if pages == 0:
            pages = 1
        if x > 0 and x + it["w"] > size:
            x = 0
            y += shelf + pad
            shelf = 0
        if y + it["h"] > size:
            pages += 1
            x = 0
            y = 0
            shelf = 0
        placements.append({"name": it["name"], "page": pages, "x": x, "y": y})
        x += it["w"] + pad
        shelf = max(shelf, it["h"])
        used += it["w"] * it["h"]
    var waste: float = 0.0 if pages == 0 else 1.0 - float(used) / (pages * size * size)
    if pages > int(opts["max_pages"]):
        issues.append(_issue("warning", "page_budget", "", 0, "%d pages needed (budget %d)." % [pages, opts["max_pages"]], "Use a larger page, split the atlas by scene, or downscale sprites."))
    if pages > 0 and waste > float(opts["max_waste"]):
        issues.append(_issue("info", "high_waste", "", 0, "%.0f%% of page area is empty." % (waste * 100.0), "A smaller page size or a MaxRects packer may fit better."))
    return _finish({"sprites": items.size(), "pages": pages, "page_size": size, "waste": snappedf(waste, 0.001)}, issues, {"placements": placements})


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
    var lines: Array = ["# Texture Atlas Packing Planner", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
