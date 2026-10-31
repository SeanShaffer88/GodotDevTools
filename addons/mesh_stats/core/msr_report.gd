## Mesh Statistics Report - glTF/GLB counts.
## Reads the glTF JSON (embedded in .glb or a .gltf file) and counts, per mesh
## primitive, vertices (POSITION accessor count) and triangles (index count / 3
## for triangle lists, strips and fans by their own rules, or vertices / 3
## without indices). Totals are per file, counting each mesh once per node that
## uses it. Buffers are never decoded.
extends RefCounted

const EXTS: Array[String] = ["gltf", "glb"]
const DEFAULTS := {"max_triangles": 50000, "max_materials": 8}


func run(input: String = "res://", options: Dictionary = {}) -> Dictionary:
    if DirAccess.open(input) == null:
        return _fail(input, "Cannot open scan directory.", "Provide an existing readable project directory.")
    var paths: Array = []
    _walk(input, paths)
    paths.sort()
    var docs := {}
    for p in paths:
        docs[p] = gltf_json(FileAccess.get_file_as_bytes(p), str(p).get_extension() == "glb")
    return analyze(docs, options)


## Parse the glTF JSON from .gltf text bytes or a .glb container; null when unreadable.
func gltf_json(b: PackedByteArray, glb: bool) -> Variant:
    if not glb:
        return JSON.parse_string(b.get_string_from_utf8())
    if b.size() < 20 or b.slice(0, 4).get_string_from_ascii() != "glTF":
        return null
    var length := b.decode_u32(12)
    if b.slice(16, 20).get_string_from_ascii() != "JSON" or 20 + length > b.size():
        return null
    return JSON.parse_string(b.slice(20, 20 + length).get_string_from_utf8())


func analyze(docs: Dictionary, options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    var issues: Array = []
    var files: Array = []
    for path in docs.keys():
        var g: Variant = docs[path]
        if typeof(g) != TYPE_DICTIONARY:
            issues.append(_issue("error", "bad_gltf", str(path), 0, "Not readable glTF 2.0 JSON.", "Re-export the file; Draco-compressed and glTF 1.0 files are not supported."))
            continue
        var accessors: Array = g.get("accessors", [])
        var meshes: Array = g.get("meshes", [])
        var uses := {}
        for n in g.get("nodes", []):
            if typeof(n) == TYPE_DICTIONARY and n.has("mesh"):
                uses[int(n["mesh"])] = int(uses.get(int(n["mesh"]), 0)) + 1
        if uses.is_empty():
            for i in range(meshes.size()):
                uses[i] = 1
        var tris := 0
        var verts := 0
        var prims := 0
        var mats := {}
        for mi in uses.keys():
            if mi >= meshes.size():
                continue
            for p in meshes[mi].get("primitives", []):
                prims += 1
                var vcount := 0
                if p.get("attributes", {}).has("POSITION") and int(p["attributes"]["POSITION"]) < accessors.size():
                    vcount = int(accessors[int(p["attributes"]["POSITION"])].get("count", 0))
                var icount := vcount
                if p.has("indices") and int(p["indices"]) < accessors.size():
                    icount = int(accessors[int(p["indices"])].get("count", 0))
                var mode := int(p.get("mode", 4))
                var t := 0
                if mode == 4:
                    t = icount / 3
                elif mode in [5, 6]:
                    t = max(0, icount - 2)
                tris += t * int(uses[mi])
                verts += vcount * int(uses[mi])
                if p.has("material"):
                    mats[int(p["material"])] = true
                if vcount > 65535:
                    issues.append(_issue("info", "large_primitive", str(path), 0, "A primitive of mesh %s has %d vertices (needs 32-bit indices)." % [meshes[mi].get("name", mi), vcount], "Fine on desktop; split it if you target devices that prefer 16-bit indices."))
        files.append({"path": str(path), "triangles": tris, "vertices": verts, "primitives": prims, "materials": mats.size()})
        if tris > int(opts["max_triangles"]):
            issues.append(_issue("warning", "triangle_budget", str(path), 0, "%d triangles (budget %d)." % [tris, opts["max_triangles"]], "Decimate the mesh or add LODs (Godot can generate LODs on import)."))
        if mats.size() > int(opts["max_materials"]):
            issues.append(_issue("warning", "material_budget", str(path), 0, "%d materials (budget %d); each is at least one draw call." % [mats.size(), opts["max_materials"]], "Merge materials with a texture atlas or trim sheet."))
    return _finish({"files": files.size()}, issues, {"files": files})


func _markdown_extra(result: Dictionary) -> Array:
    var out: Array = ["| File | Triangles | Vertices | Primitives | Materials |", "|---|---|---|---|---|"]
    for f in result.get("files", []):
        out.append("| `%s` | %d | %d | %d | %d |" % [f["path"], f["triangles"], f["vertices"], f["primitives"], f["materials"]])
    out.append("")
    return out


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
    var lines: Array = ["# Mesh Statistics Report", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
