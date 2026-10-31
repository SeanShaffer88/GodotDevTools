## LOD and Visibility Range Planner - range and LOD checks.
## Checks GeometryInstance3D visibility_range_begin/end pairs, finds scene
## nodes that instance glTF/GLB models heavier than a triangle threshold with
## no visibility range set, and reads model .import files for
## meshes/generate_lods=false. Triangle counts come from glTF accessor
## metadata, like the Mesh Statistics Report.
extends RefCounted

const EXTS: Array[String] = ["tscn", "import"]
const DEFAULTS := {"heavy_triangles": 5000}


func run(input: String = "res://", options: Dictionary = {}) -> Dictionary:
    if DirAccess.open(input) == null:
        return _fail(input, "Cannot open scan directory.", "Provide an existing readable project directory.")
    var paths: Array = []
    _walk(input, paths)
    paths.sort()
    var texts := {}
    var models := {}
    for p in paths:
        texts[p] = FileAccess.get_file_as_string(p)
        if str(p).get_extension() == "tscn":
            for m in RegEx.create_from_string("path=\"(res://[^\"]+\\.(?:gltf|glb))\"").search_all(str(texts[p])):
                var mp := m.get_string(1)
                if not models.has(mp) and FileAccess.file_exists(mp):
                    models[mp] = triangles(FileAccess.get_file_as_bytes(mp), mp.get_extension() == "glb")
    return analyze(texts, _with(options, models))


func _with(options: Dictionary, models: Dictionary) -> Dictionary:
    var o: Dictionary = options.duplicate()
    o["models"] = models
    return o


## Triangle count of a glTF/GLB from accessor metadata (each mesh once per node).
func triangles(b: PackedByteArray, glb: bool) -> int:
    var g: Variant = null
    if glb:
        if b.size() >= 20 and b.slice(0, 4).get_string_from_ascii() == "glTF":
            g = JSON.parse_string(b.slice(20, 20 + b.decode_u32(12)).get_string_from_utf8())
    else:
        g = JSON.parse_string(b.get_string_from_utf8())
    if typeof(g) != TYPE_DICTIONARY:
        return 0
    var acc: Array = g.get("accessors", [])
    var meshes: Array = g.get("meshes", [])
    var uses := {}
    for n in g.get("nodes", []):
        if typeof(n) == TYPE_DICTIONARY and n.has("mesh"):
            uses[int(n["mesh"])] = int(uses.get(int(n["mesh"]), 0)) + 1
    var total := 0
    for mi in uses.keys():
        if mi >= meshes.size():
            continue
        for p in meshes[mi].get("primitives", []):
            var idx := int(p.get("indices", p.get("attributes", {}).get("POSITION", -1)))
            if idx >= 0 and idx < acc.size():
                total += int(acc[idx].get("count", 0)) / 3 * int(uses[mi])
    return total


func analyze(texts: Dictionary, options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    var models: Dictionary = options.get("models", {})
    var issues: Array = []
    var ranged := 0
    for path in texts.keys():
        if texts[path] == null:
            issues.append(_issue("error", "scan_error", str(path), 0, "Cannot read file.", "Check file permissions and retry."))
            continue
        var text := str(texts[path])
        if str(path).ends_with(".import"):
            var src := str(path).trim_suffix(".import")
            if src.get_extension() in ["gltf", "glb", "fbx", "blend", "obj"] and text.contains("meshes/generate_lods=false"):
                issues.append(_issue("info", "lods_disabled", str(path), 0, "LOD generation is off for %s." % src.get_file(), "Enable Meshes > Generate LODs in the Import dock unless the model is always close to the camera."))
            continue
        var ext := {}
        var node := {}
        var lines := (text + "\n[end]").split("\n")
        for index in range(lines.size()):
            var s := lines[index].strip_edges()
            if s.begins_with("[ext_resource"):
                ext[s.get_slice(" id=\"", 1).get_slice("\"", 0)] = s.get_slice(" path=\"", 1).get_slice("\"", 0)
            if s.begins_with("["):
                if not node.is_empty():
                    _check_node(node, models, opts, str(path), issues)
                    if node.has("end") or node.has("begin"):
                        ranged += 1
                node = {}
                if s.begins_with("[node "):
                    node = {"name": s.get_slice("name=\"", 1).get_slice("\"", 0), "line": index + 1, "model": ""}
                    if s.contains("instance=ExtResource(\""):
                        node["model"] = str(ext.get(s.get_slice("instance=ExtResource(\"", 1).get_slice("\"", 0), ""))
            elif not node.is_empty() and s.begins_with("visibility_range_begin = "):
                node["begin"] = float(s.get_slice(" = ", 1))
            elif not node.is_empty() and s.begins_with("visibility_range_end = "):
                node["end"] = float(s.get_slice(" = ", 1))
    return _finish({"nodes_with_ranges": ranged, "models_measured": models.size()}, issues)


func _check_node(node: Dictionary, models: Dictionary, opts: Dictionary, path: String, issues: Array) -> void:
    var begin := float(node.get("begin", 0.0))
    var end := float(node.get("end", 0.0))
    if end > 0.0 and end <= begin:
        issues.append(_issue("warning", "invalid_range", path, node["line"], "%s: visibility range end %.1f is not beyond begin %.1f; it never shows." % [node["name"], end, begin], "Set end above begin (or 0 to disable the far limit)."))
    var model: String = node["model"]
    if model != "" and models.has(model) and int(models[model]) > int(opts["heavy_triangles"]) and not node.has("end"):
        issues.append(_issue("info", "no_visibility_range", path, node["line"], "%s instances %s (%d triangles) with no visibility range." % [node["name"], model.get_file(), models[model]], "Set visibility_range_end (with a cheaper fallback via visibility_parent) or rely on generated LODs."))


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
    var lines: Array = ["# LOD and Visibility Range Planner", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
