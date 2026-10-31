## Static scene dependency graph. Paths referenced dynamically cannot be proven unused.
extends RefCounted

const TEXT_EXTENSIONS := ["tscn", "tres", "gd", "gdshader", "gdshaderinc", "cs"]
const ASSET_EXTENSIONS := ["tscn", "tres", "res", "gd", "cs", "gdshader", "gdshaderinc", "png", "jpg", "jpeg", "webp", "svg", "wav", "ogg", "mp3", "glb", "gltf", "fbx", "ttf", "otf"]

func _walk(dir_path: String, files: Array) -> void:
    var dir := DirAccess.open(dir_path)
    if dir == null:
        return
    dir.list_dir_begin()
    var name := dir.get_next()
    while name != "":
        if not name.begins_with(".") and name != "addons":
            var path := dir_path.path_join(name)
            if dir.current_is_dir():
                _walk(path, files)
            elif name.get_extension().to_lower() in ASSET_EXTENSIONS:
                files.append(path)
        name = dir.get_next()
    dir.list_dir_end()

## Finds literal project paths in text resources and scripts, including load/preload.
## This is deliberately conservative: a quoted path is a possible dependency.
func references(text: String) -> Array:
    var regex := RegEx.new()
    regex.compile("[\\\"'](res://[^\\\"'\\r\\n]+|uid://[^\\\"'\\r\\n]+)[\\\"']")
    var found: Array = []
    for match_result in regex.search_all(text):
        var path := match_result.get_string(1)
        if path not in found:
            found.append(path)
    found.sort()
    return found

func _resolve(path: String) -> String:
    if path.begins_with("uid://"):
        var id := ResourceUID.text_to_id(path)
        if ResourceUID.has_id(id):
            return ResourceUID.get_id_path(id)
    return path

func project_autoloads() -> Dictionary:
    var result := {}
    var cfg := ConfigFile.new()
    if cfg.load("res://project.godot") == OK and cfg.has_section("autoload"):
        for key in cfg.get_section_keys("autoload"):
            result[key] = _resolve(str(cfg.get_value("autoload", key, "")).trim_prefix("*"))
    return result

func project_roots() -> Array:
    var roots: Array = []
    var cfg := ConfigFile.new()
    if cfg.load("res://project.godot") != OK:
        return roots
    var main := str(cfg.get_value("application", "run/main_scene", ""))
    if main != "":
        roots.append(_resolve(main))
    if cfg.has_section("autoload"):
        for key in cfg.get_section_keys("autoload"):
            var path := str(cfg.get_value("autoload", key, "")).trim_prefix("*")
            if path != "" and path not in roots:
                roots.append(_resolve(path))
    roots.sort()
    return roots

func run(scan_dir: String = "res://", roots: Array = []) -> Dictionary:
    var paths: Array = []
    _walk(scan_dir, paths)
    paths.sort()
    var files := {}
    for path in paths:
        var ext := str(path).get_extension().to_lower()
        files[path] = FileAccess.get_file_as_string(path) if ext in TEXT_EXTENSIONS else ""
    var result := analyze(files, project_roots() if roots.is_empty() else roots)
    result["autoloads"] = project_autoloads()
    return result

## Analyze an explicit path -> text inventory. Non-text assets use empty text.
func analyze(files: Dictionary, roots: Array, chain_limit: int = 8) -> Dictionary:
    var nodes: Array = files.keys()
    nodes.sort()
    var adjacency := {}
    var edges: Array = []
    var issues: Array = []
    for path in nodes:
        adjacency[path] = []
        for raw_target in references(str(files[path])):
            var target := _resolve(str(raw_target))
            edges.append({"from": path, "to": target})
            if files.has(target):
                (adjacency[path] as Array).append(target)
            elif target.begins_with("uid://"):
                issues.append(_issue("warning", "unresolved_uid", str(path), "UID reference %s cannot be resolved by this static scan." % target, "Resolve the UID in Godot and inspect its dependencies manually."))
            elif not FileAccess.file_exists(target):
                issues.append(_issue("error", "missing_dependency", str(path), "Reference to missing path %s." % target, "Restore the file or update the reference."))
    var reachable := {}
    var stack: Array = []
    for root in roots:
        stack.append(_resolve(str(root)))
    while not stack.is_empty():
        var node = stack.pop_back()
        if reachable.has(node) or not adjacency.has(node):
            continue
        reachable[node] = true
        for target in adjacency[node]:
            stack.append(target)
    var missing_roots: Array = []
    for root in roots:
        if not adjacency.has(_resolve(str(root))):
            missing_roots.append(root)
    if reachable.is_empty() or not missing_roots.is_empty():
        issues.append(_issue("warning", "no_roots", "project.godot", "Some or all entry points are outside the scanned inventory or unresolved; unused candidates are suppressed.", "Scan all entry points or supply explicit roots within the scan directory."))
    else:
        for path in nodes:
            if not reachable.has(path):
                issues.append(_issue("info", "unused_candidate", str(path), "Not reachable from the configured entry points: %s." % path, "Check dynamic loads, editor use and additional entry points before removing this file."))
    var state := {}
    var chain: Array = []
    for path in nodes:
        if not state.has(path):
            _visit(path, adjacency, state, chain, issues, maxi(chain_limit, 2))
    return {"summary": {"nodes": nodes.size(), "edges": edges.size(), "roots": roots.size(), "reachable": reachable.size(), "issues": issues.size()}, "nodes": nodes, "edges": edges, "roots": roots, "issues": issues}

func _visit(node: String, adjacency: Dictionary, state: Dictionary, chain: Array, issues: Array, limit: int) -> void:
    state[node] = 1
    chain.append(node)
    if chain.size() == limit:
        issues.append(_issue("warning", "long_chain", node, "Dependency chain reaches %d files: %s" % [chain.size(), " -> ".join(chain)], "Review coupling and consider breaking the chain."))
    for target in adjacency[node]:
        if int(state.get(target, 0)) == 1:
            var start := chain.find(target)
            var cycle := chain.slice(start)
            cycle.append(target)
            issues.append(_issue("warning", "cycle", node, "Dependency cycle: %s" % " -> ".join(cycle), "Break the circular dependency or verify initialization order."))
        elif int(state.get(target, 0)) == 0:
            _visit(target, adjacency, state, chain, issues, limit)
    chain.pop_back()
    state[node] = 2

func _issue(severity: String, kind: String, path: String, message: String, fix: String) -> Dictionary:
    return {"severity": severity, "kind": kind, "path": path, "message": message, "fix": fix}

func to_json(result: Dictionary) -> String:
    return JSON.stringify(result, "  ")

func to_markdown(result: Dictionary) -> String:
    var lines: Array[String] = ["# Scene Dependency Map", "", "Summary: " + str(result["summary"]), "", "## Entry points"]
    for root in result["roots"]:
        lines.append("- `" + str(root) + "`")
    lines.append_array(["", "## Dependencies"])
    for edge in result["edges"]:
        lines.append("- `%s` → `%s`" % [edge["from"], edge["to"]])
    lines.append_array(["", "## Findings"])
    for issue in result["issues"]:
        lines.append("- **%s** `%s`: %s %s" % [issue["kind"], issue["path"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
