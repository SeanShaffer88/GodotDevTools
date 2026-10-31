## Node Path Breakage Detector - static node-path resolution.
## Finds literal node paths in GDScript ($Name/Child, $"Quoted", get_node("..."),
## %Unique) and resolves each one from the node the script is attached to, in
## every scene that attaches it, following instanced child scenes. A path that
## resolves in no owning scene is reported. Nodes added by code at runtime are
## invisible to this check. Read-only.
extends RefCounted

const EXTS: Array[String] = ["gd", "tscn"]
const DEFAULTS := {"report_unattached": false}

var _dollar_re := RegEx.create_from_string("\\$(\"[^\"]+\"|[A-Za-z_][A-Za-z0-9_]*(?:/[A-Za-z_][A-Za-z0-9_]*)*)")
var _getnode_re := RegEx.create_from_string("get_node(?:_or_null)?\\(\\s*\"([^\"]+)\"\\s*\\)")
var _unique_re := RegEx.create_from_string("(?:^|[^A-Za-z0-9_\"'])%([A-Za-z_][A-Za-z0-9_]*)")


## Scene text -> {nodes: {path: true}, scripts: {path: script}, instances: {path: scene}, unique: {name: path}}
func parse_scene(text: String) -> Dictionary:
    var ext := {}
    var nodes := {}
    var scripts := {}
    var instances := {}
    var unique := {}
    var current := ""
    for raw in text.split("\n"):
        var line := raw.strip_edges()
        if line.begins_with("[ext_resource"):
            ext[_attr(line, "id")] = _attr(line, "path")
            current = ""
        elif line.begins_with("[node "):
            var name := _attr(line, "name")
            var parent := _attr(line, "parent")
            if not line.contains(" parent="):
                current = "."
            elif parent == ".":
                current = name
            else:
                current = parent + "/" + name
            nodes[current] = true
            var marker := "instance=ExtResource(\""
            var i := line.find(marker)
            if i >= 0:
                var id := line.substr(i + marker.length()).get_slice("\"", 0)
                instances[current] = str(ext.get(id, ""))
        elif line.begins_with("["):
            current = ""
        elif current != "" and line.begins_with("script = ExtResource(\""):
            scripts[current] = str(ext.get(line.trim_prefix("script = ExtResource(\"").get_slice("\"", 0), ""))
        elif current != "" and line == "unique_name_in_owner = true":
            unique[current.get_file() if current != "." else "."] = current
    return {"nodes": nodes, "scripts": scripts, "instances": instances, "unique": unique}


## Literal node references in a script: [{line, path, unique}].
func references(text: String) -> Array:
    var out: Array = []
    var lines := text.split("\n")
    for index in range(lines.size()):
        var code := _strip_comment(lines[index])
        if code.strip_edges().begins_with("func ") or code.strip_edges() == "":
            pass
        for m in _dollar_re.search_all(code):
            var p := m.get_string(1).trim_prefix("\"").trim_suffix("\"")
            out.append({"line": index + 1, "path": p, "unique": p.begins_with("%")})
        for m in _getnode_re.search_all(code):
            var q := m.get_string(1)
            out.append({"line": index + 1, "path": q, "unique": q.begins_with("%")})
        for m in _unique_re.search_all(code):
            if code.find("$%" + m.get_string(1)) >= 0:
                continue
            # skip string-format operators like "%d" % x by requiring an identifier after %
            var before := code.substr(0, m.get_start(1) - 1)
            if before.count("\"") % 2 == 1:
                continue
            out.append({"line": index + 1, "path": "%" + m.get_string(1), "unique": true})
    return out


func _strip_comment(line: String) -> String:
    var in_str := false
    for i in range(line.length()):
        var c := line[i]
        if c == "\"":
            in_str = not in_str
        elif c == "#" and not in_str:
            return line.substr(0, i)
    return line


## Resolve a relative path from `from` inside `scene`, descending into instances.
func resolve(scenes: Dictionary, scene: String, from: String, path: String, depth: int = 0) -> bool:
    if depth > 16 or not scenes.has(scene):
        return false
    var info: Dictionary = scenes[scene]
    var parts: Array = []
    if from != ".":
        parts.append_array(from.split("/"))
    for part in path.split("/", false):
        if part == "..":
            if parts.is_empty():
                return false
            parts.pop_back()
        elif part != ".":
            parts.append(part)
    var acc := ""
    for i in range(parts.size()):
        acc = parts[i] if acc == "" else acc + "/" + parts[i]
        if not info["nodes"].has(acc):
            return false
        if info["instances"].has(acc) and i < parts.size() - 1:
            var rest := "/".join(parts.slice(i + 1))
            return resolve(scenes, info["instances"][acc], ".", rest, depth + 1)
    return true


func analyze(texts: Dictionary, options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    var issues: Array = []
    var scenes := {}
    var owners := {}  # script -> [[scene, node]]
    var checked := 0
    var dynamic := 0
    for path in texts.keys():
        if texts[path] == null:
            issues.append(_issue("error", "scan_error", str(path), 0, "Cannot read file.", "Check file permissions and retry."))
        elif str(path).get_extension() == "tscn":
            scenes[path] = parse_scene(str(texts[path]))
    for scene in scenes.keys():
        for node in scenes[scene]["scripts"].keys():
            var script: String = scenes[scene]["scripts"][node]
            if not owners.has(script):
                owners[script] = []
            owners[script].append([scene, node])
    for path in texts.keys():
        if texts[path] == null or str(path).get_extension() != "gd":
            continue
        var refs := references(str(texts[path]))
        if refs.is_empty():
            continue
        if not owners.has(path):
            if opts["report_unattached"]:
                issues.append(_issue("info", "unattached_script", str(path), 0, "Script uses node paths but no scanned scene attaches it.", "Nothing to check against; attach it in a scene or ignore."))
            continue
        for ref in refs:
            var p: String = ref["path"]
            if p.begins_with("/") or p.contains("{") or p.contains("%s"):
                dynamic += 1
                continue
            checked += 1
            var ok := false
            for owner in owners[path]:
                if ref["unique"]:
                    var info: Dictionary = scenes[owner[0]]
                    var uname := p.trim_prefix("%").get_slice("/", 0)
                    if info["unique"].has(uname):
                        var rest := p.trim_prefix("%").substr(uname.length()).trim_prefix("/")
                        ok = rest == "" or resolve(scenes, owner[0], info["unique"][uname], rest)
                else:
                    ok = resolve(scenes, owner[0], owner[1], p)
                if ok:
                    break
            if not ok:
                var kind := "missing_unique" if ref["unique"] else "broken_path"
                issues.append(_issue("warning", kind, str(path), int(ref["line"]),
                    "`%s` does not resolve in %s." % [p, ", ".join(owners[path].map(func(o): return "%s (%s)" % [o[0], o[1]]))],
                    "Fix the path, add the node to the scene, or mark it unique_name_in_owner if it is meant to be %Name. If code adds it at runtime, ignore this finding."))
    return _finish({"scenes": scenes.size(), "references_checked": checked, "dynamic_skipped": dynamic}, issues)


func _attr(line: String, key: String) -> String:
    var marker := " " + key + "=\""
    var i := line.find(marker)
    if i < 0:
        return ""
    var start := i + marker.length()
    return line.substr(start, line.find("\"", start) - start)

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
    var lines: Array = ["# Node Path Breakage Detector", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
