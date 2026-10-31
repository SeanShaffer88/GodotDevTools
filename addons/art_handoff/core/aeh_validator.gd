## Art-to-Engine Handoff Validator - export hygiene.
## Reads glTF JSON (embedded in .glb or .gltf) and checks what usually goes
## wrong between a DCC tool and the engine: node scale not applied (not
## 1,1,1), model extent (POSITION accessor min/max times node scale) outside
## a plausible metre range, DCC default names for materials and animations,
## textured materials on primitives without TEXCOORD_0, and node names using
## a Godot import hint suffix that is misspelt.
extends RefCounted

const EXTS: Array[String] = ["gltf", "glb"]
const DEFAULTS := {"min_size": 0.05, "max_size": 500.0}
const SUFFIXES: Array[String] = ["-col", "-colonly", "-convcol", "-convcolonly", "-noimp", "-rigid", "-vehicle", "-wheel", "-navmesh", "-occ", "-occonly", "-loop", "-cycle", "-anim"]
var _default_re := RegEx.create_from_string("^(Material|Material\\.\\d+|Action|Action\\.\\d+|ArmatureAction(\\.\\d+)?|lambert\\d+|phong\\d+|blinn\\d+|DefaultMaterial|None|Scene|Take 001)$")


func run(input: String = "res://", options: Dictionary = {}) -> Dictionary:
    if DirAccess.open(input) == null:
        return _fail(input, "Cannot open scan directory.", "Provide an existing readable project directory.")
    var paths: Array = []
    _walk(input, paths)
    paths.sort()
    var docs := {}
    for p in paths:
        var b := FileAccess.get_file_as_bytes(p)
        if str(p).get_extension() == "glb":
            docs[p] = JSON.parse_string(b.slice(20, 20 + b.decode_u32(12)).get_string_from_utf8()) if b.size() >= 20 and b.slice(0, 4).get_string_from_ascii() == "glTF" else null
        else:
            docs[p] = JSON.parse_string(b.get_string_from_utf8())
    return evaluate(docs, _opts(options))


func evaluate(docs: Dictionary, options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    var issues: Array = []
    for path in docs.keys():
        var g: Variant = docs[path]
        if typeof(g) != TYPE_DICTIONARY:
            issues.append(_issue("error", "bad_gltf", str(path), 0, "Not readable glTF 2.0 JSON.", "Re-export the file."))
            continue
        var acc: Array = g.get("accessors", [])
        var meshes: Array = g.get("meshes", [])
        var mats: Array = g.get("materials", [])
        for n in g.get("nodes", []):
            var name := str(n.get("name", ""))
            var sc: Array = n.get("scale", [1, 1, 1])
            if sc.any(func(v): return absf(float(v) - 1.0) > 0.001):
                issues.append(_issue("warning", "unapplied_scale", str(path), 0, "Node %s has scale %s." % [name, sc], "Apply scale in the DCC tool before export so physics, LOD and lighting see true sizes."))
            if name.contains("-"):
                var suffix := "-" + name.get_slice("-", name.get_slice_count("-") - 1).to_lower()
                if suffix not in SUFFIXES and suffix.length() <= 12 and RegEx.create_from_string("^-(col|conv|occ|nav|noimp|rigid|loop|cycle|anim)").search(suffix) != null:
                    issues.append(_issue("warning", "unknown_suffix", str(path), 0, "Node %s ends in %s, which looks like a Godot import hint but is not one." % [name, suffix], "Use one of: %s." % ", ".join(SUFFIXES)))
            if n.has("mesh") and int(n["mesh"]) < meshes.size():
                var lo := Vector3(INF, INF, INF)
                var hi := Vector3(-INF, -INF, -INF)
                for p in meshes[int(n["mesh"])].get("primitives", []):
                    var pi := int(p.get("attributes", {}).get("POSITION", -1))
                    if pi >= 0 and pi < acc.size() and acc[pi].has("min") and acc[pi].has("max"):
                        lo = lo.min(Vector3(acc[pi]["min"][0], acc[pi]["min"][1], acc[pi]["min"][2]))
                        hi = hi.max(Vector3(acc[pi]["max"][0], acc[pi]["max"][1], acc[pi]["max"][2]))
                    var mi := int(p.get("material", -1))
                    if mi >= 0 and mi < mats.size() and not p.get("attributes", {}).has("TEXCOORD_0"):
                        var pbr: Dictionary = mats[mi].get("pbrMetallicRoughness", {})
                        if pbr.has("baseColorTexture") or pbr.has("metallicRoughnessTexture") or mats[mi].has("normalTexture"):
                            issues.append(_issue("error", "missing_uv", str(path), 0, "Mesh of node %s uses textured material %s but has no UVs." % [name, mats[mi].get("name", mi)], "Unwrap the mesh (TEXCOORD_0) before export."))
                if lo.x != INF:
                    var extent := (hi - lo) * Vector3(float(sc[0]), float(sc[1]), float(sc[2])).abs()
                    var biggest: float = max(extent.x, max(extent.y, extent.z))
                    if biggest < float(opts["min_size"]) or biggest > float(opts["max_size"]):
                        issues.append(_issue("warning", "size_suspect", str(path), 0, "Node %s is %.3f m across." % [name, biggest], "Check export units (centimetres vs metres) and scale."))
        for kind in [["materials", "material"], ["animations", "animation"]]:
            for item in g.get(kind[0], []):
                var nm := str(item.get("name", ""))
                if nm == "" or _default_re.search(nm) != null:
                    issues.append(_issue("info", "default_name", str(path), 0, "Default %s name '%s'." % [kind[1], nm], "Give it a meaningful name; Godot uses it for imported resources and animation names."))
    return _finish({"files": docs.size()}, issues)


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
    var lines: Array = ["# Art-to-Engine Handoff Validator", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
