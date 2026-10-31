## Shader Variant Budget Manager - variant inventory.
## Godot generates and compiles one shader per distinct combination of
## BaseMaterial3D (StandardMaterial3D / ORMMaterial3D) feature settings, so
## the number of distinct combinations approximates material shader variants
## (and pipeline compilations / stutter risk). Custom .gdshader files with
## preprocessor conditionals can produce up to 2^n variants. Counts are
## static estimates from resource text.
extends RefCounted

const EXTS: Array[String] = ["tscn", "tres", "gdshader", "gdshaderinc"]
const DEFAULTS := {"max_variants": 32, "max_defines": 2}
## Non-"_enabled" properties that change the generated shader.
const FEATURE_KEYS: Array[String] = ["transparency", "shading_mode", "blend_mode", "cull_mode", "depth_draw_mode", "diffuse_mode",
    "specular_mode", "billboard_mode", "no_depth_test", "vertex_color_use_as_albedo", "vertex_color_is_srgb", "uv1_triplanar",
    "uv2_triplanar", "fixed_size", "use_point_size", "use_particle_trails", "texture_filter", "albedo_texture_force_srgb", "distance_fade_mode"]

var _define_re := RegEx.create_from_string("^\\s*#(?:ifdef|ifndef|if|elif)\\s+(?:defined\\s*\\(\\s*)?([A-Za-z_][A-Za-z0-9_]*)")


func analyze(texts: Dictionary, options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    var issues: Array = []
    var combos := {}
    for path in texts.keys():
        if texts[path] == null:
            issues.append(_issue("error", "scan_error", str(path), 0, "Cannot read file.", "Check file permissions and retry."))
            continue
        var ext := str(path).get_extension()
        var text := str(texts[path])
        if ext in ["gdshader", "gdshaderinc"]:
            var defines := {}
            for line in text.split("\n"):
                var m := _define_re.search(line)
                if m != null:
                    defines[m.get_string(1)] = true
            if defines.size() > int(opts["max_defines"]):
                issues.append(_issue("info", "preprocessor_variants", str(path), 0, "%d preprocessor keywords (%s): up to %d variants if all combinations are used." % [defines.size(), ", ".join(defines.keys()), 1 << defines.size()], "Prefer uniforms for cheap toggles; keep #ifdef for features that must compile away."))
            continue
        var current := {}
        var cls := ""
        var where := ""
        for raw in (text + "\n[end]").split("\n"):
            var s := raw.strip_edges()
            if s.begins_with("["):
                if cls != "":
                    var key := cls + "|" + ",".join(_sorted_pairs(current))
                    if not combos.has(key):
                        combos[key] = []
                    combos[key].append(where)
                cls = ""
                current = {}
                var t := s.get_slice("type=\"", 1).get_slice("\"", 0) if s.contains("type=\"") else ""
                if t in ["StandardMaterial3D", "ORMMaterial3D"] and s.begins_with("[sub_resource"):
                    cls = t
                    where = "%s (%s)" % [path, s.get_slice("id=\"", 1).get_slice("\"", 0) if s.contains("id=\"") else "resource"]
                elif s == "[resource]" and (text.begins_with("[gd_resource type=\"StandardMaterial3D\"") or text.begins_with("[gd_resource type=\"ORMMaterial3D\"")):
                    cls = text.get_slice("type=\"", 1).get_slice("\"", 0)
                    where = str(path)
            elif cls != "" and s.contains(" = "):
                var k := s.get_slice(" = ", 0)
                if k.ends_with("_enabled") or k in FEATURE_KEYS:
                    current[k] = s.substr(k.length() + 3)
    var variants: Array = []
    for key in combos.keys():
        variants.append({"features": key, "materials": combos[key].size(), "examples": combos[key].slice(0, 3)})
    variants.sort_custom(func(a, b): return int(a["materials"]) > int(b["materials"]))
    if combos.size() > int(opts["max_variants"]):
        issues.append(_issue("warning", "variant_budget", "res://", 0, "%d distinct material feature combinations (budget %d)." % [combos.size(), opts["max_variants"]], "Merge similar materials, standardize feature flags, or move per-object differences into textures and uniforms."))
    for v in variants:
        if int(v["materials"]) == 1 and combos.size() > int(opts["max_variants"]):
            issues.append(_issue("info", "single_use_variant", str(v["examples"][0]), 0, "Feature set used by one material only: %s." % str(v["features"]).get_slice("|", 1), "Align it with a common material setup if the look allows."))
    return _finish({"material_variants": combos.size()}, issues, {"variants": variants})


func _sorted_pairs(d: Dictionary) -> Array:
    var keys: Array = d.keys()
    keys.sort()
    return keys.map(func(k): return "%s=%s" % [k, d[k]])

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
    var lines: Array = ["# Shader Variant Budget Manager", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
