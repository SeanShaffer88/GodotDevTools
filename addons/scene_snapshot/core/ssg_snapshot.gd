## Scene Review Snapshot Generator - reviewable scene inventory.
## A snapshot maps each node path to its type (or instanced scene), script
## path, groups and stored properties, with ext_resource ids replaced by
## their paths so snapshots compare across files. The CLI writes
## snapshot.json; with a comparison (older scene or snapshot) it reports
## added and removed nodes and changed types, scripts and properties: a
## readable review of a scene change without opening the editor.
extends RefCounted

const EXTS: Array[String] = ["tscn"]
const DEFAULTS := {"compare": ""}


func run(input: String = "", options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    if not FileAccess.file_exists(input):
        return _fail(input, "Scene not found.", "Pass --scene=<.tscn>.", "bad_input")
    var snap := snapshot(FileAccess.get_file_as_string(input))
    var old: Variant = null
    var c := str(opts["compare"])
    if c != "":
        if not FileAccess.file_exists(c):
            return _fail(c, "Comparison file not found.", "Pass an older .tscn or a snapshot .json.", "bad_input")
        old = _read_json(c) if c.get_extension() == "json" else snapshot(FileAccess.get_file_as_string(c))
        if typeof(old) != TYPE_DICTIONARY:
            return _fail(c, "Comparison snapshot is not a JSON object.", "Use a snapshot.json written by this tool.", "bad_input")
    return evaluate(snap, old, input)


func snapshot(text: String) -> Dictionary:
    var ext := {}
    var nodes := {}
    var cur: Dictionary = {}
    for raw in text.split("\n"):
        var s := raw.strip_edges()
        if s.begins_with("[ext_resource"):
            ext[s.get_slice(" id=\"", 1).get_slice("\"", 0)] = s.get_slice(" path=\"", 1).get_slice("\"", 0)
            cur = {}
        elif s.begins_with("[node "):
            var name := s.get_slice("name=\"", 1).get_slice("\"", 0)
            var parent := s.get_slice("parent=\"", 1).get_slice("\"", 0) if s.contains("parent=\"") else ""
            var path := "." if parent == "" else (name if parent == "." else parent + "/" + name)
            var type := s.get_slice("type=\"", 1).get_slice("\"", 0) if s.contains("type=\"") else ""
            if s.contains("instance=ExtResource(\""):
                type = "instance:" + str(ext.get(s.get_slice("instance=ExtResource(\"", 1).get_slice("\"", 0), "?"))
            cur = {"type": type, "script": "", "groups": s.get_slice("groups=", 1).get_slice("]", 0) + "]" if s.contains("groups=") else "", "props": {}}
            nodes[path] = cur
        elif s.begins_with("["):
            cur = {}
        elif not cur.is_empty() and s.contains(" = "):
            var k := s.get_slice(" = ", 0)
            var v := s.substr(k.length() + 3)
            for id in ext.keys():
                v = v.replace("ExtResource(\"%s\")" % id, "ExtResource(\"%s\")" % ext[id])
            if k == "script":
                cur["script"] = v.get_slice("\"", 1)
            else:
                cur["props"][k] = v
    return {"format": 1, "nodes": nodes}


func evaluate(snap: Dictionary, old: Variant = null, path: String = "") -> Dictionary:
    var issues: Array = []
    if old != null:
        var a: Dictionary = old.get("nodes", {})
        var b: Dictionary = snap["nodes"]
        var keys: Array = b.keys()
        keys.sort()
        for k in keys:
            if not a.has(k):
                issues.append(_issue("info", "node_added", path, 0, "%s (%s) added." % [k, b[k]["type"]], "Review the new node."))
                continue
            if a[k]["type"] != b[k]["type"]:
                issues.append(_issue("warning", "type_changed", path, 0, "%s type %s -> %s." % [k, a[k]["type"], b[k]["type"]], "Confirm scripts and signals still fit the new type."))
            if a[k]["script"] != b[k]["script"]:
                issues.append(_issue("warning", "script_changed", path, 0, "%s script %s -> %s." % [k, a[k]["script"] if a[k]["script"] != "" else "(none)", b[k]["script"] if b[k]["script"] != "" else "(none)"], "Confirm the behaviour change is intended."))
            var props: Array = a[k]["props"].keys()
            for p in b[k]["props"].keys():
                if p not in props:
                    props.append(p)
            props.sort()
            for p in props:
                var va: String = str(a[k]["props"].get(p, "(default)"))
                var vb: String = str(b[k]["props"].get(p, "(default)"))
                if va != vb:
                    issues.append(_issue("info", "property_changed", path, 0, "%s.%s: %s -> %s." % [k, p, va, vb], "Review the value change."))
        var removed: Array = a.keys().filter(func(k): return not b.has(k))
        removed.sort()
        for k in removed:
            issues.append(_issue("warning", "node_removed", path, 0, "%s (%s) removed." % [k, a[k]["type"]], "Check nothing references the removed node (the Node Path Breakage Detector helps)."))
    return _finish({"nodes": snap["nodes"].size(), "compared": old != null}, issues, {"artifacts": {"snapshot.json": JSON.stringify(snap, "  ", true)}})


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
    var lines: Array = ["# Scene Review Snapshot Generator", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
