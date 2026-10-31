## Node Property Drift Monitor - convention drift.
## Without a baseline: for every node type and stored property (layout,
## transform, text and resource properties ignored), collect values across
## scenes; when at least min_nodes store it and one value holds the majority
## share, the rest are reported as outliers. With a baseline
## ({"Label": {"horizontal_alignment": "1"}}) every stored or default value
## is compared. Values compare as scene text.
extends RefCounted

const EXTS: Array[String] = ["tscn"]
const DEFAULTS := {"baseline": "", "min_nodes": 5, "majority": 0.7}
const IGNORE: Array[String] = ["position", "rotation", "scale", "size", "text", "script", "layout_mode", "anchors_preset", "anchor_left", "anchor_top", "anchor_right", "anchor_bottom",
    "offset_left", "offset_top", "offset_right", "offset_bottom", "grow_horizontal", "grow_vertical", "texture", "unique_name_in_owner", "transform", "polygon", "points", "shape", "mesh", "stream"]


func run(input: String = "res://", options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    if str(opts["baseline"]) != "":
        var b: Variant = _read_json(str(opts["baseline"]))
        if typeof(b) != TYPE_DICTIONARY:
            return _fail(str(opts["baseline"]), "Baseline missing or not a JSON object.", "Write {\"Label\": {\"horizontal_alignment\": \"1\"}}.", "bad_baseline")
        opts["baseline_data"] = b
    if DirAccess.open(input) == null:
        return _fail(input, "Cannot open scan directory.", "Provide an existing readable project directory.")
    var paths: Array = []
    _walk(input, paths)
    paths.sort()
    var texts := {}
    for p in paths:
        texts[p] = FileAccess.get_file_as_string(p)
    return analyze(texts, opts)


func analyze(texts: Dictionary, options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    var nodes: Array = []
    for path in texts.keys():
        if texts[path] == null:
            continue
        var cur: Dictionary = {}
        var lines := str(texts[path]).split("\n")
        for index in range(lines.size()):
            var s := lines[index].strip_edges()
            if s.begins_with("[node ") and s.contains("type=\""):
                cur = {"path": str(path), "line": index + 1, "name": s.get_slice("name=\"", 1).get_slice("\"", 0), "type": s.get_slice("type=\"", 1).get_slice("\"", 0), "props": {}}
                nodes.append(cur)
            elif s.begins_with("["):
                cur = {}
            elif not cur.is_empty() and s.contains(" = "):
                var k := s.get_slice(" = ", 0)
                if k not in IGNORE and not k.begins_with("metadata/"):
                    cur["props"][k] = s.substr(k.length() + 3)
    var issues: Array = []
    if opts.has("baseline_data"):
        var base: Dictionary = opts["baseline_data"]
        for n in nodes:
            if not base.has(n["type"]):
                continue
            for k in base[n["type"]].keys():
                var want := str(base[n["type"]][k])
                var have := str(n["props"].get(k, "(default)"))
                if have != want:
                    issues.append(_issue("warning", "baseline_mismatch", n["path"], n["line"], "%s (%s).%s is %s, baseline %s." % [n["name"], n["type"], k, have, want], "Match the baseline or update it with team agreement."))
        return _finish({"nodes": nodes.size(), "mode": "baseline"}, issues)
    var stats := {}
    for n in nodes:
        for k in n["props"].keys():
            var key := "%s|%s" % [n["type"], k]
            if not stats.has(key):
                stats[key] = {}
            var v: String = n["props"][k]
            if not stats[key].has(v):
                stats[key][v] = []
            stats[key][v].append(n)
    var conventions := {}
    for key in stats.keys():
        var total := 0
        var best := ""
        for v in stats[key].keys():
            total += stats[key][v].size()
            if best == "" or stats[key][v].size() > stats[key][best].size():
                best = v
        if total < int(opts["min_nodes"]) or float(stats[key][best].size()) / total < float(opts["majority"]) or stats[key].size() < 2:
            continue
        conventions[key] = best
        for v in stats[key].keys():
            if v == best:
                continue
            for n in stats[key][v]:
                issues.append(_issue("info", "property_outlier", n["path"], n["line"], "%s (%s).%s = %s; %d of %d stored values are %s." % [n["name"], n["type"], key.get_slice("|", 1), v, stats[key][best].size(), total, best], "Align it with the convention, or document why this node differs."))
    return _finish({"nodes": nodes.size(), "conventions": conventions.size(), "mode": "learned"}, issues, {"conventions": conventions})


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
    var lines: Array = ["# Node Property Drift Monitor", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
