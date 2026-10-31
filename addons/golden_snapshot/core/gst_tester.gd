## Golden Data Snapshot Tester - JSON path diffs.
## Pairs files by relative path between a current-output folder and a golden
## folder, parses both as JSON and walks them together, reporting each
## difference with its JSON path (e.g. enemies[2].hp). Numbers equal within
## the tolerance match. Updating goldens is a deliberate copy, never done
## by this tool.
extends RefCounted

const EXTS: Array[String] = ["json"]
const DEFAULTS := {"golden": "res://tests/golden", "tolerance": 0.000001, "max_per_file": 50}


func run(input: String = "", options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    for d in [input, str(opts["golden"])]:
        if DirAccess.open(d) == null:
            return _fail(d, "Folder not found.", "Pass --current=<outputs folder> and --golden=<goldens folder>.", "bad_input")
    var cur: Array = []
    var gold: Array = []
    _walk(input, cur)
    _walk(str(opts["golden"]), gold)
    var pairs := {}
    for p in cur:
        pairs[str(p).trim_prefix(input)] = [FileAccess.get_file_as_string(p), null]
    for p in gold:
        var rel := str(p).trim_prefix(str(opts["golden"]))
        if not pairs.has(rel):
            pairs[rel] = [null, null]
        pairs[rel][1] = FileAccess.get_file_as_string(p)
    return evaluate(pairs, opts)


## pairs: {relative path: [current text or null, golden text or null]}
func evaluate(pairs: Dictionary, options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    var issues: Array = []
    var keys: Array = pairs.keys()
    keys.sort()
    var differing := 0
    for rel in keys:
        var cur: Variant = pairs[rel][0]
        var gold: Variant = pairs[rel][1]
        if cur == null:
            issues.append(_issue("warning", "missing_output", rel, 0, "Golden exists but this run produced no output.", "Check that the producing step still runs, or delete the stale golden."))
            continue
        if gold == null:
            issues.append(_issue("info", "missing_golden", rel, 0, "Output has no golden yet.", "Review it and copy it into the golden folder to approve it."))
            continue
        var a: Variant = JSON.parse_string(str(cur))
        var b: Variant = JSON.parse_string(str(gold))
        if a == null or b == null:
            issues.append(_issue("error", "bad_json", rel, 0, "Output or golden is not valid JSON.", "Fix the producer or the golden."))
            continue
        var diffs: Array = []
        _diff(b, a, "$", float(opts["tolerance"]), diffs)
        if not diffs.is_empty():
            differing += 1
        for d in diffs.slice(0, int(opts["max_per_file"])):
            issues.append(_issue("warning", d[0], rel, 0, d[1], "If the change is intended, approve it by copying the output over the golden."))
    return _finish({"files": keys.size(), "differing": differing}, issues)


func _diff(gold: Variant, cur: Variant, path: String, tol: float, out: Array) -> void:
    var tg := typeof(gold)
    var tc := typeof(cur)
    var numeric := [TYPE_INT, TYPE_FLOAT]
    if tg in numeric and tc in numeric:
        if absf(float(gold) - float(cur)) > tol:
            out.append(["changed_value", "%s: %s -> %s" % [path, gold, cur]])
        return
    if tg != tc:
        out.append(["type_changed", "%s: %s -> %s" % [path, type_string(tg), type_string(tc)]])
        return
    if tg == TYPE_DICTIONARY:
        var keys: Array = gold.keys()
        for k in cur.keys():
            if k not in keys:
                keys.append(k)
        keys.sort()
        for k in keys:
            var sub := "%s.%s" % [path, k]
            if not cur.has(k):
                out.append(["removed_key", "%s removed (was %s)" % [sub, _short(gold[k])]])
            elif not gold.has(k):
                out.append(["added_key", "%s added: %s" % [sub, _short(cur[k])]])
            else:
                _diff(gold[k], cur[k], sub, tol, out)
    elif tg == TYPE_ARRAY:
        for i in range(max(gold.size(), cur.size())):
            var sub := "%s[%d]" % [path, i]
            if i >= cur.size():
                out.append(["removed_key", "%s removed (was %s)" % [sub, _short(gold[i])]])
            elif i >= gold.size():
                out.append(["added_key", "%s added: %s" % [sub, _short(cur[i])]])
            else:
                _diff(gold[i], cur[i], sub, tol, out)
    elif gold != cur:
        out.append(["changed_value", "%s: %s -> %s" % [path, _short(gold), _short(cur)]])


func _short(v: Variant) -> String:
    var s := JSON.stringify(v)
    return s if s.length() <= 60 else s.substr(0, 57) + "..."


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
    var lines: Array = ["# Golden Data Snapshot Tester", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
