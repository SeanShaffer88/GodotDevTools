## Scene Load Smoke Tester - headless load check.
## For each scene: ResourceLoader.load, PackedScene.instantiate, then free.
## Scenes are never added to the tree, so _ready and _process do not run,
## but scripts' _init does. Dependencies listed by ResourceLoader that do not
## exist are reported, and node types in the scene state that ClassDB does
## not know (removed or renamed engine classes) are reported, since Godot
## silently replaces them with placeholders.
extends RefCounted

const EXTS: Array[String] = ["tscn", "scn"]
const DEFAULTS := {}


func run(input: String = "res://", options: Dictionary = {}) -> Dictionary:
    if DirAccess.open(input) == null:
        return _fail(input, "Cannot open scan directory.", "Provide an existing readable project directory.")
    var paths: Array = []
    _walk(input, paths)
    paths.sort()
    var issues: Array = []
    var ok := 0
    for p in paths:
        var found := check_scene(str(p))
        issues.append_array(found)
        if found.filter(func(i): return i["kind"] in ["load_failed", "instantiate_failed"]).is_empty():
            ok += 1
    return _finish({"scenes": paths.size(), "loaded": ok}, issues)


func check_scene(path: String) -> Array:
    var issues: Array = []
    for dep in ResourceLoader.get_dependencies(path):
        var dep_path := str(dep).get_slice("::", str(dep).get_slice_count("::") - 1) if str(dep).contains("::") else str(dep)
        if dep_path != "" and not ResourceLoader.exists(dep_path) and not FileAccess.file_exists(dep_path):
            issues.append(_issue("error", "missing_dependency", path, 0, "Depends on %s, which does not exist." % dep_path, "Restore the file or re-point the reference (the Scene Dependency Map lists every reference)."))
    var res: Variant = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
    if res == null or not res is PackedScene:
        issues.append(_issue("error", "load_failed", path, 0, "Scene did not load.", "Open it in the editor to see the parse error."))
        return issues
    var state: SceneState = res.get_state()
    for i in range(state.get_node_count()):
        var type := state.get_node_type(i)
        if type != "" and not ClassDB.class_exists(type) and not _is_script_class(type):
            issues.append(_issue("error", "unknown_type", path, 0, "Node %s has type %s, which this Godot version does not have; a placeholder is created." % [state.get_node_path(i), type], "Change the node to its Godot 4 equivalent (e.g. KinematicBody2D -> CharacterBody2D)."))
    var node: Node = res.instantiate()
    if node == null:
        issues.append(_issue("error", "instantiate_failed", path, 0, "Scene loaded but instantiate() returned null.", "Open it in the editor; check inherited scenes and editable children."))
    else:
        node.free()
    return issues


func _is_script_class(type: String) -> bool:
    for c in ProjectSettings.get_global_class_list():
        if str(c.get("class", "")) == type:
            return true
    return false


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
    var lines: Array = ["# Scene Load Smoke Tester", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
