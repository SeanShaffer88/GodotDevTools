## Environment Feature Cost Matrix - enabled feature inventory.
## Reads Environment sub-resources in scenes and Environment .tres files and
## lists enabled features. Cost tiers are this tool's relative ranking for
## comparing setups, not measurements. Features the Compatibility renderer
## does not implement are flagged when it is the project renderer.
extends RefCounted

const EXTS: Array[String] = ["tscn", "tres"]
## Scene text -> {nodes: [{path, type, props, line}], instances: [{node, scene}], subs: {id: {type, props}}}
func parse_scene(text: String) -> Dictionary:
    var ext := {}
    var nodes: Array = []
    var instances: Array = []
    var subs := {}
    var current: Dictionary = {}
    var lines := text.split("\n")
    for index in range(lines.size()):
        var s := lines[index].strip_edges()
        if s.begins_with("[ext_resource"):
            ext[_attr(s, "id")] = _attr(s, "path")
            current = {}
        elif s.begins_with("[sub_resource"):
            current = {"type": _attr(s, "type"), "props": {}, "line": index + 1}
            subs[_attr(s, "id")] = current
        elif s.begins_with("[resource]"):
            current = {"type": "_resource", "props": {}, "line": index + 1}
            subs["_resource"] = current
        elif s.begins_with("[node "):
            var name := _attr(s, "name")
            var parent := _attr(s, "parent")
            var path := "." if not s.contains(" parent=") else (name if parent == "." else parent + "/" + name)
            current = {"path": path, "type": _attr(s, "type"), "props": {}, "line": index + 1}
            nodes.append(current)
            var i := s.find("instance=ExtResource(\"")
            if i >= 0:
                instances.append({"node": path, "scene": str(ext.get(s.substr(i + 22).get_slice("\"", 0), ""))})
        elif s.begins_with("["):
            current = {}
        elif not current.is_empty() and s.contains(" = "):
            current["props"][s.get_slice(" = ", 0)] = s.substr(s.get_slice(" = ", 0).length() + 3)
    return {"nodes": nodes, "instances": instances, "subs": subs}


func _attr(line: String, key: String) -> String:
    var marker := " " + key + "=\""
    var i := line.find(marker)
    if i < 0:
        return ""
    var start := i + marker.length()
    return line.substr(start, line.find("\"", start) - start)

const DEFAULTS := {"max_cost": "medium", "renderer": ""}
const TIERS := {"low": 1, "medium": 2, "high": 3}
## property -> [label, relative tier]
const FEATURES := {
    "sdfgi_enabled": ["SDFGI", "high"], "ssr_enabled": ["Screen-space reflections", "high"],
    "ssil_enabled": ["Screen-space indirect lighting", "high"], "volumetric_fog_enabled": ["Volumetric fog", "high"],
    "ssao_enabled": ["Screen-space ambient occlusion", "medium"], "glow_enabled": ["Glow", "low"],
    "fog_enabled": ["Depth fog", "low"], "adjustment_enabled": ["Colour adjustments", "low"]}
## Features the Compatibility renderer does not implement (Godot 4.3 renderer comparison).
const NOT_IN_COMPATIBILITY: Array[String] = ["sdfgi_enabled", "ssr_enabled", "ssil_enabled", "ssao_enabled", "volumetric_fog_enabled"]


func run(input: String = "res://", options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    if not TIERS.has(str(opts["max_cost"])):
        return _fail("max_cost", "max_cost must be low, medium or high.", "Pass --max-cost=low|medium|high.", "bad_input")
    if DirAccess.open(input) == null:
        return _fail(input, "Cannot open scan directory.", "Provide an existing readable project directory.")
    if str(opts["renderer"]) == "":
        opts["renderer"] = "forward_plus"
        if FileAccess.file_exists("res://project.godot"):
            for line in FileAccess.get_file_as_string("res://project.godot").split("\n"):
                if line.begins_with("renderer/rendering_method=\""):
                    opts["renderer"] = line.get_slice("\"", 1)
    var paths: Array = []
    _walk(input, paths)
    paths.sort()
    var texts := {}
    for p in paths:
        texts[p] = FileAccess.get_file_as_string(p)
    return analyze(texts, opts)


func analyze(texts: Dictionary, options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    var limit := int(TIERS.get(str(opts["max_cost"]), 2))
    var issues: Array = []
    var envs: Array = []
    for path in texts.keys():
        if texts[path] == null:
            issues.append(_issue("error", "scan_error", str(path), 0, "Cannot read file.", "Check file permissions and retry."))
            continue
        var text := str(texts[path])
        if not text.contains("Environment"):
            continue
        var parsed := parse_scene(text)
        var is_env_res := text.begins_with("[gd_resource type=\"Environment\"")
        for id in parsed["subs"].keys():
            var sub: Dictionary = parsed["subs"][id]
            if sub["type"] != "Environment" and not (id == "_resource" and is_env_res):
                continue
            var enabled: Array = []
            for prop in FEATURES.keys():
                if str(sub["props"].get(prop, "false")) == "true":
                    enabled.append(prop)
            envs.append({"path": str(path), "line": sub["line"], "features": enabled.map(func(p): return FEATURES[p][0])})
            for prop in enabled:
                var tier: String = FEATURES[prop][1]
                if int(TIERS[tier]) > limit:
                    issues.append(_issue("warning", "expensive_feature", str(path), sub["line"], "%s enabled (relative cost: %s, allowed: %s)." % [FEATURES[prop][0], tier, opts["max_cost"]], "Disable it for this tier or expose it as a graphics setting."))
                if str(opts["renderer"]) == "gl_compatibility" and prop in NOT_IN_COMPATIBILITY:
                    issues.append(_issue("warning", "unsupported_in_renderer", str(path), sub["line"], "%s is not available in the Compatibility renderer and will have no effect." % FEATURES[prop][0], "Remove it or switch renderer; do not rely on it for the look."))
    return _finish({"environments": envs.size(), "renderer": str(opts["renderer"])}, issues, {"environments": envs})


func _markdown_extra(result: Dictionary) -> Array:
    var out: Array = []
    for e in result.get("environments", []):
        out.append("- `%s:%d`: %s" % [e["path"], e["line"], ", ".join(e["features"]) if not e["features"].is_empty() else "(no costed features)"])
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
    var lines: Array = ["# Environment Feature Cost Matrix", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
