## 3D Light and Shadow Cost Estimator - static light counts.
## Counts OmniLight3D, SpotLight3D and DirectionalLight3D nodes per scene,
## including those inside instanced scenes, and which cast shadows
## (shadow_enabled, off by default). Each shadowed omni/spot light renders
## the scene again into the shadow atlas, and each shadowed directional light
## renders its splits every frame. Counts are capacities: lights hidden or
## disabled at runtime still count.
extends RefCounted

const EXTS: Array[String] = ["tscn"]
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

const DEFAULTS := {"max_shadowed": 4, "max_lights": 32, "renderer": ""}
## Godot's default per-object omni+spot light limits for the Mobile and Compatibility renderers.
const PER_OBJECT_LIMIT := {"mobile": 8, "gl_compatibility": 8}


func run(input: String = "res://", options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
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


func _tally(scene: String, texts: Dictionary, cache: Dictionary, stack: Array) -> Dictionary:
    if cache.has(scene):
        return cache[scene]
    var c := {"omni": 0, "spot": 0, "directional": 0, "shadow_omni_spot": 0, "shadow_directional": 0}
    if scene in stack or stack.size() > 16:
        return c
    var text: Variant = texts.get(scene)
    if text == null and FileAccess.file_exists(scene):
        text = FileAccess.get_file_as_string(scene)
    if text == null:
        return c
    var parsed := parse_scene(str(text))
    for n in parsed["nodes"]:
        var shadow: bool = str(n["props"].get("shadow_enabled", "false")) == "true"
        match n["type"]:
            "OmniLight3D":
                c["omni"] += 1
                c["shadow_omni_spot"] += int(shadow)
            "SpotLight3D":
                c["spot"] += 1
                c["shadow_omni_spot"] += int(shadow)
            "DirectionalLight3D":
                c["directional"] += 1
                c["shadow_directional"] += int(shadow)
    for inst in parsed["instances"]:
        var child := _tally(inst["scene"], texts, cache, stack + [scene])
        for k in c.keys():
            c[k] += int(child[k])
    cache[scene] = c
    return c


func analyze(texts: Dictionary, options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    var issues: Array = []
    var cache := {}
    var scenes: Array = []
    for path in texts.keys():
        if texts[path] == null:
            issues.append(_issue("error", "scan_error", str(path), 0, "Cannot read file.", "Check file permissions and retry."))
            continue
        var c := _tally(str(path), texts, cache, [])
        var lights: int = c["omni"] + c["spot"]
        if lights + int(c["directional"]) == 0:
            continue
        var row := c.duplicate()
        row["path"] = str(path)
        scenes.append(row)
        if int(c["shadow_omni_spot"]) > int(opts["max_shadowed"]):
            issues.append(_issue("warning", "shadow_budget", str(path), 0, "%d shadow-casting omni/spot lights (budget %d)." % [c["shadow_omni_spot"], opts["max_shadowed"]], "Turn shadows off on small or distant lights, or bake lighting (LightmapGI)."))
        if lights > int(opts["max_lights"]):
            issues.append(_issue("warning", "light_budget", str(path), 0, "%d omni/spot lights (budget %d)." % [lights, opts["max_lights"]], "Merge nearby lights or bake static ones."))
        if int(c["shadow_directional"]) > 1:
            issues.append(_issue("warning", "multiple_directional_shadows", str(path), 0, "%d directional lights cast shadows." % c["shadow_directional"], "Keep one shadowed directional light; others rarely need shadows."))
        var limit := int(PER_OBJECT_LIMIT.get(str(opts["renderer"]), 0))
        if limit > 0 and lights > limit:
            issues.append(_issue("info", "renderer_light_limit", str(path), 0, "%d omni/spot lights in one scene with the %s renderer, whose default per-object limit is %d." % [lights, opts["renderer"], limit], "Lights beyond the limit are skipped on meshes they overlap; spread them out or bake them."))
    return _finish({"scenes_with_lights": scenes.size(), "renderer": str(opts["renderer"])}, issues, {"scenes": scenes})


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
    var lines: Array = ["# 3D Light and Shadow Cost Estimator", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
