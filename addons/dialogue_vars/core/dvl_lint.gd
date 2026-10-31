## Dialogue Variable Lint - variable flow in dialogue data.
## Reads JSON dialogue files in the Dialogue and Quest Debugger format
## (choices with condition {var, op, value} or a list of them, and effects
## {var: value}), then compares variables read with variables written.
## Variables set by game code are declared with the external list.
extends RefCounted

const EXTS: Array[String] = ["json"]
const DEFAULTS := {"external": []}


func analyze(texts: Dictionary, options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    var issues: Array = []
    var reads := {}
    var writes := {}
    var files := 0
    for path in texts.keys():
        if texts[path] == null:
            issues.append(_issue("error", "scan_error", str(path), 0, "Cannot read file.", "Check file permissions and retry."))
            continue
        var text := str(texts[path])
        if not (text.contains("\"dialogues\"") or text.contains("\"quests\"")):
            continue
        var data: Variant = JSON.parse_string(text)
        if typeof(data) != TYPE_DICTIONARY:
            continue
        files += 1
        var dialogues: Dictionary = data.get("dialogues", {}) if typeof(data.get("dialogues", {})) == TYPE_DICTIONARY else {}
        for did in dialogues.keys():
            var nodes: Dictionary = dialogues[did].get("nodes", {}) if typeof(dialogues[did]) == TYPE_DICTIONARY else {}
            for nid in nodes.keys():
                var node: Variant = nodes[nid]
                if typeof(node) != TYPE_DICTIONARY:
                    continue
                for choice in node.get("choices", []):
                    if typeof(choice) != TYPE_DICTIONARY:
                        continue
                    var where := "%s/%s" % [did, nid]
                    var cond: Variant = choice.get("condition")
                    var conds: Array = cond if typeof(cond) == TYPE_ARRAY else ([cond] if typeof(cond) == TYPE_DICTIONARY else [])
                    for c in conds:
                        if typeof(c) == TYPE_DICTIONARY and c.has("var"):
                            _add(reads, str(c["var"]), str(path), where, c.get("value"))
                    var eff: Variant = choice.get("effects")
                    if typeof(eff) == TYPE_DICTIONARY:
                        for k in eff.keys():
                            _add(writes, str(k), str(path), where, eff[k])
    var external: Array = opts["external"]
    for v in reads.keys():
        if not writes.has(v) and v not in external:
            var r: Dictionary = reads[v][0]
            issues.append(_issue("warning", "read_never_set", r["path"], 0, "`%s` is read at %s (and %d more) but no effect sets it." % [v, r["where"], reads[v].size() - 1], "Set it in an effect, or list it with --external if game code sets it."))
        elif writes.has(v):
            var rt := typeof(reads[v][0]["value"])
            var wt := typeof(writes[v][0]["value"])
            var numeric := [TYPE_INT, TYPE_FLOAT]
            if rt != wt and not (rt in numeric and wt in numeric):
                issues.append(_issue("info", "type_mismatch", reads[v][0]["path"], 0, "`%s` is compared with %s at %s but set to %s at %s." % [v, type_string(rt), reads[v][0]["where"], type_string(wt), writes[v][0]["where"]], "Use one type for the variable everywhere."))
    for v in writes.keys():
        if not reads.has(v):
            var w: Dictionary = writes[v][0]
            issues.append(_issue("info", "set_never_read", w["path"], 0, "`%s` is set at %s but no condition reads it." % [v, w["where"]], "Read it in a condition, or check that game code reads it."))
    return _finish({"files": files, "variables_read": reads.size(), "variables_set": writes.size()}, issues)


func _add(target: Dictionary, name: String, path: String, where: String, value: Variant) -> void:
    if not target.has(name):
        target[name] = []
    target[name].append({"path": path, "where": where, "value": value})

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
    var lines: Array = ["# Dialogue Variable Lint", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
