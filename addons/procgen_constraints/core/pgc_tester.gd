## Procedural Generation Constraint Tester - layout constraints.
## Dump your generator's output for many seeds as text grids (# wall, . floor,
## S start, E exit, K key, D door; anything else is floor). Each map is
## flood-filled from S with doors closed, then again with doors open once the
## key is reachable. Reports maps whose exit cannot be reached, keys locked
## behind their own door, floor pockets unreachable from the start, and a
## high share of dead-end cells. The summary gives the failure rate across
## seeds.
extends RefCounted

const EXTS: Array[String] = ["map", "txt"]
const DEFAULTS := {"max_dead_end_ratio": 0.25}
const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


func parse_map(text: String) -> Dictionary:
    var cells := {}
    var special := {}
    var rows := text.strip_edges().split("\n")
    for y in range(rows.size()):
        var row := rows[y].strip_edges(false, true)
        for x in range(row.length()):
            var c := row[x]
            if c == "#" or c == " ":
                continue
            cells[Vector2i(x, y)] = c
            if c in ["S", "E", "K", "D"]:
                special[c] = Vector2i(x, y)
    return {"cells": cells, "special": special}


func flood(cells: Dictionary, start: Vector2i, doors_open: bool) -> Dictionary:
    var seen := {start: true}
    var stack: Array = [start]
    while not stack.is_empty():
        var p: Vector2i = stack.pop_back()
        for d in DIRS:
            var q: Vector2i = p + d
            if cells.has(q) and not seen.has(q) and (doors_open or cells[q] != "D"):
                seen[q] = true
                stack.append(q)
    return seen


func check_map(text: String, opts: Dictionary) -> Array:
    var m := parse_map(text)
    var cells: Dictionary = m["cells"]
    var sp: Dictionary = m["special"]
    if not sp.has("S") or not sp.has("E"):
        return [["error", "bad_map", "Map needs S (start) and E (exit)."]]
    var problems: Array = []
    var closed := flood(cells, sp["S"], false)
    var final := closed
    if not closed.has(sp["E"]):
        if sp.has("D") and sp.has("K") and not closed.has(sp["K"]) and flood(cells, sp["S"], true).has(sp["E"]):
            problems.append(["error", "key_behind_door", "The key is only reachable through its own door."])
        elif sp.has("D") and sp.has("K") and closed.has(sp["K"]):
            final = flood(cells, sp["S"], true)
            if not final.has(sp["E"]):
                problems.append(["error", "unreachable_exit", "The exit cannot be reached even with the door open."])
        else:
            problems.append(["error", "unreachable_exit", "The exit cannot be reached from the start."])
    elif sp.has("D") and sp.has("K"):
        final = flood(cells, sp["S"], true)
    var pockets := cells.size() - final.size()
    if pockets > 0 and problems.is_empty():
        problems.append(["info", "isolated_pocket", "%d floor cells cannot be reached from the start." % pockets])
    var dead := 0
    for p in final.keys():
        var n := 0
        for d in DIRS:
            if cells.has(p + d):
                n += 1
        if n == 1 and cells[p] == ".":
            dead += 1
    var ratio: float = float(dead) / max(1, final.size())
    if ratio > float(opts["max_dead_end_ratio"]):
        problems.append(["info", "high_dead_end_ratio", "%.0f%% of reachable cells are dead ends." % (ratio * 100.0)])
    return problems


func analyze(texts: Dictionary, options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    var issues: Array = []
    var failed := 0
    var paths: Array = texts.keys()
    paths.sort()
    for path in paths:
        if texts[path] == null:
            issues.append(_issue("error", "scan_error", str(path), 0, "Cannot read file.", "Check file permissions and retry."))
            continue
        var problems := check_map(str(texts[path]), opts)
        if problems.any(func(p): return p[0] == "error"):
            failed += 1
        for p in problems:
            issues.append(_issue(p[0], p[1], str(path), 0, p[2], "Fix the generator rule that produced this seed; keep the map as a regression fixture."))
    return _finish({"maps": paths.size(), "failed": failed, "failure_rate": snappedf(float(failed) / max(1, paths.size()), 0.001)}, issues)

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
    var lines: Array = ["# Procedural Generation Constraint Tester", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
