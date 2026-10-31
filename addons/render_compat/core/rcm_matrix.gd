## Rendering Settings Compatibility Matrix - feature support check.
## Collects node types (VoxelGI, LightmapGI, FogVolume, ReflectionProbe,
## Decal, GPUParticles3D...) and Environment feature flags used in scenes and
## resources, then checks them against a matrix of features each renderer
## does not implement. The built-in matrix only lists Compatibility-renderer
## gaps this project is confident of for Godot 4.3; extend it with --matrix
## from the renderer comparison in the Godot documentation for your version.
extends RefCounted

const EXTS: Array[String] = ["tscn", "tres"]
func _renderer(opts: Dictionary) -> String:
    if str(opts.get("renderer", "")) != "":
        return str(opts["renderer"])
    if FileAccess.file_exists("res://project.godot"):
        for line in FileAccess.get_file_as_string("res://project.godot").split("\n"):
            if line.begins_with("renderer/rendering_method=\""):
                return line.get_slice("\"", 1)
    return "forward_plus"

const DEFAULTS := {"renderer": "", "matrix": ""}
const BUILTIN := {"gl_compatibility": ["VoxelGI", "FogVolume", "sdfgi_enabled", "ssr_enabled", "ssao_enabled", "ssil_enabled", "volumetric_fog_enabled"], "mobile": [], "forward_plus": []}
const NODE_FEATURES: Array[String] = ["VoxelGI", "LightmapGI", "FogVolume", "ReflectionProbe", "Decal", "GPUParticles3D", "GPUParticlesCollisionSDF3D", "GPUParticlesAttractorBox3D", "WorldEnvironment", "OccluderInstance3D"]
const ENV_FEATURES: Array[String] = ["sdfgi_enabled", "ssr_enabled", "ssao_enabled", "ssil_enabled", "volumetric_fog_enabled", "glow_enabled", "fog_enabled"]


func run(input: String = "res://", options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    var matrix: Variant = BUILTIN
    if str(opts["matrix"]) != "":
        matrix = _read_json(str(opts["matrix"]))
        if typeof(matrix) != TYPE_DICTIONARY:
            return _fail(str(opts["matrix"]), "Matrix missing or not a JSON object.", "Write {\"mobile\": [\"VoxelGI\"]}.", "bad_matrix")
    if DirAccess.open(input) == null:
        return _fail(input, "Cannot open scan directory.", "Provide an existing readable project directory.")
    var paths: Array = []
    _walk(input, paths)
    paths.sort()
    var texts := {}
    for p in paths:
        texts[p] = FileAccess.get_file_as_string(p)
    return analyze(texts, {"renderer": _renderer(opts), "matrix_data": matrix})


func analyze(texts: Dictionary, options: Dictionary = {}) -> Dictionary:
    var renderer := str(options.get("renderer", "forward_plus"))
    var matrix: Dictionary = options.get("matrix_data", BUILTIN)
    var unsupported: Array = matrix.get(renderer, [])
    var issues: Array = []
    var used := {}
    var paths: Array = texts.keys()
    paths.sort()
    for path in paths:
        if texts[path] == null:
            issues.append(_issue("error", "scan_error", str(path), 0, "Cannot read file.", "Check file permissions and retry."))
            continue
        var lines := str(texts[path]).split("\n")
        for index in range(lines.size()):
            var s := lines[index].strip_edges()
            var feature := ""
            if s.begins_with("[node ") and s.contains("type=\""):
                var t := s.get_slice("type=\"", 1).get_slice("\"", 0)
                if t in NODE_FEATURES:
                    feature = t
            elif s.ends_with(" = true") and s.get_slice(" = ", 0) in ENV_FEATURES:
                feature = s.get_slice(" = ", 0)
            if feature == "":
                continue
            if not used.has(feature):
                used[feature] = []
            used[feature].append("%s:%d" % [path, index + 1])
            if feature in unsupported:
                issues.append(_issue("warning", "unsupported_feature", str(path), index + 1, "%s is not implemented by the %s renderer." % [feature, renderer], "Remove it, provide a fallback for this renderer, or switch renderer."))
    return _finish({"renderer": renderer, "features_used": used.size()}, issues, {"features": used})


func _markdown_extra(result: Dictionary) -> Array:
    var out: Array = ["| Feature | Uses |", "|---|---|"]
    for f in result.get("features", {}).keys():
        out.append("| %s | %d |" % [f, result["features"][f].size()])
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
    var lines: Array = ["# Rendering Settings Compatibility Matrix", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
