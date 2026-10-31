## Editor Action Macro Recorder - repeatable property edits.
## A macro is a list of steps {node | selector, property, value}: `node` is
## a path from the scene root (as recorded by the dock); `selector` matches
## nodes by `type` and/or `name_pattern` (regex) so a step applies to many
## nodes or scenes. plan() instantiates nothing new: it runs over a scene
## instance and lists each change with old and new values. Writing back to a
## scene file happens only with --apply (PackedScene.pack + ResourceSaver),
## and the report lists every change made.
extends RefCounted

const EXTS: Array[String] = ["json"]
const DEFAULTS := {"scene": "", "apply": false}


func run(input: String = "", options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    var macro: Variant = _read_json(input)
    if typeof(macro) != TYPE_DICTIONARY or typeof(macro.get("steps")) != TYPE_ARRAY:
        return _fail(input, "Macro missing or without a steps array.", "See the README for the macro format.", "bad_macro")
    var problems := validate(macro)
    if not problems.is_empty():
        return _finish({"steps": macro["steps"].size()}, problems)
    if str(opts["scene"]) == "":
        return _finish({"steps": macro["steps"].size()}, [])
    var packed: Variant = load(str(opts["scene"])) if ResourceLoader.exists(str(opts["scene"])) else null
    if not packed is PackedScene:
        return _fail(str(opts["scene"]), "Scene not found.", "Pass --scene=<.tscn>.", "bad_input")
    var root: Node = packed.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
    var changes := plan(root, macro, true)
    var result := evaluate(changes, str(opts["scene"]))
    if opts["apply"] and changes.any(func(c): return c.get("matched", true) and c.get("known", true)):
        var out := PackedScene.new()
        if out.pack(root) == OK and ResourceSaver.save(out, str(opts["scene"])) == OK:
            result["issues"].append(_issue("info", "applied", str(opts["scene"]), 0, "Changes written to the scene.", "Review the diff before committing."))
            result["summary"]["applied"] = true
    root.free()
    return result


func validate(macro: Dictionary) -> Array:
    var issues: Array = []
    for n in range(macro["steps"].size()):
        var s: Variant = macro["steps"][n]
        if typeof(s) != TYPE_DICTIONARY or not s.has("property") or not s.has("value") or not (s.has("node") or s.has("selector")):
            issues.append(_issue("error", "bad_macro", "macro", n + 1, "Step %d needs node or selector, property and value." % (n + 1), "Fix the step."))
    return issues


## Convert a recorded value to JSON-safe form (vectors and colours as var_to_str text).
func to_json_step(step: Dictionary) -> Dictionary:
    var v: Variant = step["value"]
    if typeof(v) not in [TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING]:
        v = {"var": var_to_str(v)}
    return {"node": step["node"], "property": step["property"], "value": v}


func _value(v: Variant) -> Variant:
    if typeof(v) == TYPE_DICTIONARY and v.has("var"):
        return str_to_var(str(v["var"]))
    return v


func _targets(root: Node, step: Dictionary) -> Array:
    if step.has("node"):
        var n: Node = root if str(step["node"]) in [".", ""] else root.get_node_or_null(NodePath(str(step["node"])))
        return [] if n == null else [n]
    var sel: Dictionary = step["selector"]
    var re: RegEx = RegEx.create_from_string(str(sel["name_pattern"])) if sel.has("name_pattern") else null
    var out: Array = []
    var stack: Array = [root]
    while not stack.is_empty():
        var n: Node = stack.pop_back()
        if (not sel.has("type") or n.is_class(str(sel["type"]))) and (re == null or re.search(n.name) != null):
            out.append(n)
        for c in n.get_children():
            stack.append(c)
    return out


## Changes a macro would make on a scene instance: [{step, node, property, old, new, matched, known}].
## With write = true the new values are set on the instance.
func plan(root: Node, macro: Dictionary, write: bool = false) -> Array:
    var changes: Array = []
    for n in range(macro.get("steps", []).size()):
        var step: Dictionary = macro["steps"][n]
        var targets := _targets(root, step)
        if targets.is_empty():
            changes.append({"step": n + 1, "matched": false})
            continue
        for t in targets:
            var prop := str(step["property"])
            var known: bool = prop in t or t.get_property_list().any(func(p): return str(p["name"]) == prop)
            var old: Variant = t.get(prop)
            var new: Variant = _value(step["value"])
            if not known:
                changes.append({"step": n + 1, "node": str(root.get_path_to(t)), "property": prop, "matched": true, "known": false, "old": null, "new": new})
                continue
            if old == new or (typeof(old) in [TYPE_INT, TYPE_FLOAT] and typeof(new) in [TYPE_INT, TYPE_FLOAT] and float(old) == float(new)):
                continue
            changes.append({"step": n + 1, "node": str(root.get_path_to(t)), "property": prop, "old": old, "new": new, "matched": true, "known": true})
            if write:
                t.set(prop, new)
    return changes


func evaluate(changes: Array, scene: String = "") -> Dictionary:
    var issues: Array = []
    for c in changes:
        if not c.get("matched", true):
            issues.append(_issue("warning", "step_unmatched", scene, int(c["step"]), "Step %d matches no node in this scene." % c["step"], "Check the node path or selector."))
        elif not c.get("known", true):
            issues.append(_issue("warning", "unknown_property", scene, int(c["step"]), "%s has no property %s." % [c["node"], c["property"]], "Fix the property name."))
        else:
            issues.append(_issue("info", "change_preview", scene, int(c["step"]), "%s.%s: %s -> %s" % [c["node"], c["property"], c["old"], c["new"]], "Apply with --apply when the preview looks right."))
    return _finish({"changes": changes.filter(func(c): return c.get("matched", true) and c.get("known", true)).size(), "applied": false}, issues)


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
    var lines: Array = ["# Editor Action Macro Recorder", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
