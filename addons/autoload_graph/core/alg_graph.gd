## Autoload Dependency Graph - static autoload analysis.
## Reads the [autoload] section of a project file (declaration order is load
## order), opens each autoload script (or a scene's root script), and records
## which other autoload names it mentions and in which function. Reports
## reference cycles, autoloads whose file is missing, and references made
## from _init/_enter_tree/_ready to an autoload declared later, which may not
## be in the tree yet. Read-only.
extends RefCounted

const EXTS: Array[String] = ["gd", "tscn"]
## Parse Godot ConfigFile text (project.godot style) into {"section/key": value-text}.
## Multi-line values (dictionaries, arrays) are joined until brackets balance.
func parse_ini(text: String) -> Dictionary:
    var out := {}
    var section := ""
    var pending_key := ""
    var pending := ""
    var lines := text.split("\n")
    for index in range(lines.size()):
        var line: String = lines[index]
        if pending_key != "":
            pending += "\n" + line
            if _balanced(pending):
                out[pending_key] = {"value": pending.strip_edges(), "line": out[pending_key]["line"]}
                pending_key = ""
            continue
        var s := line.strip_edges()
        if s == "" or s.begins_with(";") or s.begins_with("#"):
            continue
        if s.begins_with("[") and s.ends_with("]"):
            section = s.substr(1, s.length() - 2)
            continue
        var eq := s.find("=")
        if eq < 0:
            continue
        var key := s.substr(0, eq).strip_edges()
        var full := key if section == "" else section + "/" + key
        var value := s.substr(eq + 1).strip_edges()
        out[full] = {"value": value, "line": index + 1}
        if not _balanced(value):
            pending_key = full
            pending = value
    return out


func _balanced(v: String) -> bool:
    var depth := 0
    var in_str := false
    var prev := ""
    for c in v:
        if c == "\"" and prev != "\\":
            in_str = not in_str
        elif not in_str:
            if c in ["{", "["]:
                depth += 1
            elif c in ["}", "]"]:
                depth -= 1
        prev = c
    return depth <= 0

const DEFAULTS := {}
const EARLY_FUNCS: Array[String] = ["_init", "_enter_tree", "_ready"]


func run(input: String = "res://project.godot", options: Dictionary = {}) -> Dictionary:
    if not FileAccess.file_exists(input):
        return _fail(input, "Project file not found.", "Pass --project=<path to project.godot>.", "bad_input")
    var texts := {input: FileAccess.get_file_as_string(input)}
    var entries := autoloads(str(texts[input]))
    for e in entries:
        var p: String = e["path"]
        if FileAccess.file_exists(p):
            texts[p] = FileAccess.get_file_as_string(p)
            if p.get_extension() == "tscn":
                var script := _root_script(str(texts[p]))
                if script != "" and FileAccess.file_exists(script):
                    texts[script] = FileAccess.get_file_as_string(script)
    return analyze(texts, {"project": input})


## [{name, path, line, order}] from the [autoload] section, in declaration order.
func autoloads(project_text: String) -> Array:
    var out: Array = []
    var ini := parse_ini(project_text)
    var keys: Array = ini.keys()
    keys.sort_custom(func(a, b): return int(ini[a]["line"]) < int(ini[b]["line"]))
    for key in keys:
        if str(key).begins_with("autoload/"):
            var value: String = str(ini[key]["value"]).trim_prefix("\"").trim_suffix("\"").trim_prefix("*")
            out.append({"name": str(key).trim_prefix("autoload/"), "path": value, "line": ini[key]["line"], "order": out.size()})
    return out


func analyze(texts: Dictionary, options: Dictionary = {}) -> Dictionary:
    var project: String = options.get("project", "res://project.godot")
    var issues: Array = []
    if not texts.has(project) or texts[project] == null:
        return _fail(project, "Project file not readable.", "Pass --project=<path to project.godot>.", "bad_input")
    var entries := autoloads(str(texts[project]))
    var by_name := {}
    for e in entries:
        by_name[e["name"]] = e
    var edges := {}
    for e in entries:
        edges[e["name"]] = {}
        var script: String = e["path"]
        if script.get_extension() == "tscn" and texts.has(script) and texts[script] != null:
            script = _root_script(str(texts[script]))
        if not texts.has(e["path"]) or texts[e["path"]] == null:
            issues.append(_issue("error", "missing_autoload", project, e["line"], "Autoload %s points at %s, which does not exist." % [e["name"], e["path"]], "Fix the path in Project Settings > Globals > Autoload or remove the entry."))
            continue
        if not texts.has(script) or texts[script] == null:
            continue
        var func_name := ""
        var lines := str(texts[script]).split("\n")
        for index in range(lines.size()):
            var line: String = lines[index]
            var fm := RegEx.create_from_string("^\\s*(?:static\\s+)?func\\s+([A-Za-z_][A-Za-z0-9_]*)").search(line)
            if fm != null:
                func_name = fm.get_string(1)
                continue
            var code := line.get_slice("#", 0)
            for other in by_name.keys():
                if other == e["name"]:
                    continue
                if RegEx.create_from_string("(?<![A-Za-z0-9_.])" + other + "\\b").search(code) != null:
                    if not edges[e["name"]].has(other):
                        edges[e["name"]][other] = {"line": index + 1, "function": func_name, "path": script}
                    if func_name in EARLY_FUNCS and int(by_name[other]["order"]) > int(e["order"]):
                        issues.append(_issue("warning", "init_order", script, index + 1, "%s uses %s in %s, but %s is declared later and may not be in the tree yet." % [e["name"], other, func_name, other], "Move %s above %s in the autoload list, or defer the call (call_deferred / await get_tree().process_frame)." % [other, e["name"]]))
    # cycles: DFS over edges
    var reported := {}
    for start in edges.keys():
        var cycle := _find_cycle(start, edges)
        if cycle.size() > 0:
            var key := ",".join(_canonical(cycle))
            if not reported.has(key):
                reported[key] = true
                var first: Dictionary = edges[cycle[0]][cycle[1]]
                issues.append(_issue("info", "autoload_cycle", first["path"], first["line"], "Autoload reference cycle: %s." % " -> ".join(cycle + [cycle[0]]), "Break the cycle with signals (an event bus) so one side only listens."))
    var graph := {}
    for k in edges.keys():
        graph[k] = edges[k].keys()
    return _finish({"autoloads": entries.size(), "edges": graph.values().reduce(func(acc, v): return acc + v.size(), 0)}, issues, {"order": entries.map(func(e): return e["name"]), "graph": graph})


func _find_cycle(start: String, edges: Dictionary) -> Array:
    var stack: Array = [[start, [start]]]
    while not stack.is_empty():
        var item: Array = stack.pop_back()
        var node: String = item[0]
        var path: Array = item[1]
        for nxt in edges.get(node, {}).keys():
            if nxt == start:
                return path
            if nxt not in path and edges.has(nxt):
                stack.append([nxt, path + [nxt]])
    return []


func _canonical(cycle: Array) -> Array:
    var sorted := cycle.duplicate()
    sorted.sort()
    return sorted


func _root_script(scene_text: String) -> String:
    var ext := {}
    var in_root := false
    for raw in scene_text.split("\n"):
        var line := raw.strip_edges()
        if line.begins_with("[ext_resource"):
            var i := line.find(" id=\"")
            var j := line.find(" path=\"")
            if i >= 0 and j >= 0:
                ext[line.substr(i + 5).get_slice("\"", 0)] = line.substr(j + 7).get_slice("\"", 0)
        elif line.begins_with("[node "):
            if in_root:
                return ""
            in_root = not line.contains(" parent=")
        elif in_root and line.begins_with("script = ExtResource(\""):
            return str(ext.get(line.trim_prefix("script = ExtResource(\"").get_slice("\"", 0), ""))
    return ""


func _markdown_extra(result: Dictionary) -> Array:
    var out: Array = ["Load order: " + ", ".join(result.get("order", [])), ""]
    for k in result.get("graph", {}).keys():
        out.append("- %s -> %s" % [k, ", ".join(result["graph"][k])])
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
    var lines: Array = ["# Autoload Dependency Graph", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
