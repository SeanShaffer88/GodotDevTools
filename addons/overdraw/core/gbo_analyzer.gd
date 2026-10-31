## GPU Budget and Overdraw Analyzer - static 2D estimate.
## For Sprite2D, TextureRect, ColorRect, NinePatchRect and Panel nodes, the
## drawn rectangle is computed from texture size (PNG header) or offsets,
## position and scale (rotation, parents and cameras ignored), clipped to the
## screen, and summed. Overdraw = drawn area / screen area; fill-rate =
## screen pixels x overdraw x fps. An estimate to rank scenes, not a GPU
## measurement.
extends RefCounted

const EXTS: Array[String] = ["tscn"]
const DEFAULTS := {"width": 1920, "height": 1080, "max_overdraw": 4.0, "fps": 60, "fullscreen_share": 0.9}
const DRAWABLE: Array[String] = ["Sprite2D", "TextureRect", "ColorRect", "NinePatchRect", "Panel"]


func run(input: String = "res://", options: Dictionary = {}) -> Dictionary:
    if DirAccess.open(input) == null:
        return _fail(input, "Cannot open scan directory.", "Provide an existing readable project directory.")
    var paths: Array = []
    _walk(input, paths)
    paths.sort()
    var texts := {}
    var sizes := {}
    for p in paths:
        texts[p] = FileAccess.get_file_as_string(p)
        for m in RegEx.create_from_string("path=\"(res://[^\"]+\\.png)\"").search_all(str(texts[p])):
            var tp := m.get_string(1)
            if not sizes.has(tp) and FileAccess.file_exists(tp):
                var head := FileAccess.get_file_as_bytes(tp).slice(0, 24)
                if head.size() == 24:
                    sizes[tp] = Vector2((head[16] << 24) | (head[17] << 16) | (head[18] << 8) | head[19], (head[20] << 24) | (head[21] << 16) | (head[22] << 8) | head[23])
    var o: Dictionary = options.duplicate()
    o["texture_sizes"] = sizes
    return analyze(texts, o)


func _vec(v: String) -> Vector2:
    var inner := v.get_slice("(", 1).get_slice(")", 0).split(",")
    return Vector2(float(inner[0]), float(inner[1])) if inner.size() == 2 else Vector2.ZERO


func analyze(texts: Dictionary, options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    var sizes: Dictionary = options.get("texture_sizes", {})
    var screen := Rect2(0, 0, int(opts["width"]), int(opts["height"]))
    var screen_area := screen.get_area()
    var issues: Array = []
    var scenes: Array = []
    for path in texts.keys():
        if texts[path] == null:
            issues.append(_issue("error", "scan_error", str(path), 0, "Cannot read file.", "Check file permissions and retry."))
            continue
        var ext := {}
        var nodes: Array = []
        var cur: Dictionary = {}
        for raw in str(texts[path]).split("\n"):
            var s := raw.strip_edges()
            if s.begins_with("[ext_resource"):
                ext[s.get_slice(" id=\"", 1).get_slice("\"", 0)] = s.get_slice(" path=\"", 1).get_slice("\"", 0)
            if s.begins_with("["):
                cur = {}
                if s.begins_with("[node ") and s.contains("type=\"") and s.get_slice("type=\"", 1).get_slice("\"", 0) in DRAWABLE:
                    cur = {"name": s.get_slice("name=\"", 1).get_slice("\"", 0), "type": s.get_slice("type=\"", 1).get_slice("\"", 0), "props": {}}
                    nodes.append(cur)
            elif not cur.is_empty() and s.contains(" = "):
                cur["props"][s.get_slice(" = ", 0)] = s.substr(s.get_slice(" = ", 0).length() + 3)
        var drawn := 0.0
        var full := 0
        for n in nodes:
            var p: Dictionary = n["props"]
            if str(p.get("visible", "true")) == "false":
                continue
            var rect := Rect2()
            if n["type"] == "Sprite2D":
                var tex := str(ext.get(str(p.get("texture", "")).get_slice("\"", 1), ""))
                if not sizes.has(tex):
                    continue
                var size: Vector2 = sizes[tex] * (_vec(str(p["scale"])) if p.has("scale") else Vector2.ONE)
                var pos: Vector2 = _vec(str(p["position"])) if p.has("position") else Vector2.ZERO
                if str(p.get("centered", "true")) != "false":
                    pos -= size / 2.0
                rect = Rect2(pos, size).abs()
            else:
                var l := float(p.get("offset_left", "0"))
                var t := float(p.get("offset_top", "0"))
                rect = Rect2(l, t, float(p.get("offset_right", "0")) - l, float(p.get("offset_bottom", "0")) - t).abs()
            var area := rect.intersection(screen).get_area()
            drawn += area
            if area >= screen_area * float(opts["fullscreen_share"]):
                full += 1
        if drawn <= 0.0:
            continue
        var od := drawn / screen_area
        scenes.append({"path": str(path), "overdraw": snappedf(od, 0.01), "fullscreen_layers": full, "fill_rate_mpix_s": snappedf(screen_area * od * int(opts["fps"]) / 1e6, 0.1)})
        if od > float(opts["max_overdraw"]):
            issues.append(_issue("warning", "overdraw_budget", str(path), 0, "About %.1fx overdraw at %dx%d (%.0f Mpix/s at %d fps)." % [od, opts["width"], opts["height"], screen_area * od * int(opts["fps"]) / 1e6, opts["fps"]], "Merge full-screen layers into one texture, crop transparent borders, or hide layers that are covered."))
        if full >= 3:
            issues.append(_issue("info", "stacked_fullscreen", str(path), 0, "%d layers cover the whole screen." % full, "Combine them (bake vignette/fade into one overlay or shader)."))
    return _finish({"scenes": scenes.size()}, issues, {"scenes": scenes})


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
    var lines: Array = ["# GPU Budget and Overdraw Analyzer", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
