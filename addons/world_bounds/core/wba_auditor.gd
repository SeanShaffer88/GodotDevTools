## World Boundary and Out-of-Bounds Auditor - 2D escape routes.
## Level extents come from static collision rectangles and circles. A kill
## floor is an Area2D whose name/group matches the kill pattern, or any
## WorldBoundaryShape2D; one should sit below the lowest geometry so falling
## players are caught. A side is open when no static shape spanning at least
## half the level height touches that edge. Kill zones whose rectangle
## intersects the top surface of a static floor would kill players standing
## on it.
extends RefCounted

const EXTS: Array[String] = ["tscn"]
## 2D scene text -> nodes [{name, type, path, parent, pos (global, translation only), groups, props, line}] and subs.
func parse_2d(text: String) -> Dictionary:
    var subs := {}
    var nodes: Array = []
    var by_path := {}
    var cur := {}
    var lines := text.split("\n")
    for index in range(lines.size()):
        var s := lines[index].strip_edges()
        if s.begins_with("[sub_resource"):
            cur = {"type": s.get_slice("type=\"", 1).get_slice("\"", 0), "props": {}}
            subs[s.get_slice("id=\"", 1).get_slice("\"", 0)] = cur
        elif s.begins_with("[node "):
            var name := s.get_slice("name=\"", 1).get_slice("\"", 0)
            var parent := s.get_slice("parent=\"", 1).get_slice("\"", 0) if s.contains("parent=\"") else ""
            var path := "." if parent == "" else (name if parent == "." else parent + "/" + name)
            var groups: Array = []
            if s.contains("groups=["):
                for g in RegEx.create_from_string("\"([^\"]+)\"").search_all(s.get_slice("groups=[", 1).get_slice("]", 0)):
                    groups.append(g.get_string(1))
            cur = {"name": name, "type": s.get_slice("type=\"", 1).get_slice("\"", 0) if s.contains("type=\"") else "", "path": path, "parent": parent, "groups": groups, "props": {}, "line": index + 1, "local": Vector2.ZERO}
            nodes.append(cur)
            by_path[path] = cur
        elif s.begins_with("["):
            cur = {}
        elif not cur.is_empty() and s.contains(" = "):
            var k := s.get_slice(" = ", 0)
            cur["props"][k] = s.substr(k.length() + 3)
            if k == "position" and cur.has("local"):
                cur["local"] = _v2(cur["props"][k])
    for n in nodes:
        var pos: Vector2 = n["local"]
        var parent: String = n["parent"]
        while parent != "" and by_path.has(parent):
            pos += by_path[parent]["local"]
            parent = by_path[parent]["parent"] if parent != "." else ""
        n["pos"] = pos
    return {"nodes": nodes, "subs": subs}


func _v2(v: String) -> Vector2:
    var a := v.get_slice("(", 1).get_slice(")", 0).split(",")
    return Vector2(float(a[0]), float(a[1])) if a.size() == 2 else Vector2.ZERO


## World-space Rect2 of a CollisionShape2D child (rectangle or circle), or an empty rect.
func shape_rect(scene: Dictionary, shape_node: Dictionary) -> Rect2:
    var ref := str(shape_node["props"].get("shape", "")).get_slice("\"", 1)
    if not scene["subs"].has(ref):
        return Rect2()
    var sub: Dictionary = scene["subs"][ref]
    var c: Vector2 = shape_node["pos"]
    if sub["type"] == "RectangleShape2D":
        var size := _v2(str(sub["props"].get("size", "Vector2(20, 20)")))
        return Rect2(c - size / 2.0, size)
    if sub["type"] == "CircleShape2D":
        var r := float(sub["props"].get("radius", "10"))
        return Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0)
    return Rect2()


func children_of(scene: Dictionary, path: String) -> Array:
    return scene["nodes"].filter(func(n): return n["parent"] == path)

const DEFAULTS := {"kill_pattern": "kill"}


func run(input: String = "", options: Dictionary = {}) -> Dictionary:
    if not FileAccess.file_exists(input):
        return _fail(input, "Scene not found.", "Pass --scene=<level .tscn>.", "bad_input")
    return evaluate(parse_2d(FileAccess.get_file_as_string(input)), _opts(options), input)


func evaluate(scene: Dictionary, options: Dictionary = {}, path: String = "") -> Dictionary:
    var opts := _opts(options)
    var pat := str(opts["kill_pattern"]).to_lower()
    var solids: Array = []
    var kills: Array = []
    var boundary := false
    for n in scene["nodes"]:
        var is_kill: bool = n["type"] == "Area2D" and (str(n["name"]).to_lower().contains(pat) or n["groups"].any(func(g): return str(g).to_lower().contains(pat)))
        for sh in children_of(scene, n["path"]):
            if str(sh["type"]) != "CollisionShape2D":
                continue
            var ref := str(sh["props"].get("shape", "")).get_slice("\"", 1)
            if scene["subs"].has(ref) and scene["subs"][ref]["type"] == "WorldBoundaryShape2D":
                boundary = true
                continue
            var r := shape_rect(scene, sh)
            if not r.has_area():
                continue
            if is_kill:
                kills.append([n, r])
            elif n["type"] in ["StaticBody2D", "AnimatableBody2D"]:
                solids.append([n, r])
    var issues: Array = []
    if solids.is_empty():
        return _finish({"solids": 0}, issues)
    var bounds: Rect2 = solids[0][1]
    for s in solids:
        bounds = bounds.merge(s[1])
    var below := kills.any(func(k): return k[1].position.y >= bounds.end.y - 1.0 or k[1].end.y >= bounds.end.y)
    if not below and not boundary:
        issues.append(_issue("warning", "missing_kill_floor", path, 0, "Nothing catches a fall below y = %.0f (no kill area or WorldBoundaryShape2D)." % bounds.end.y, "Add a kill/respawn Area2D or a WorldBoundaryShape2D below the level."))
    for side in ["left", "right"]:
        var edge := bounds.position.x if side == "left" else bounds.end.x
        var walled := solids.any(func(s): return (absf(s[1].position.x - edge) <= 1.0 if side == "left" else absf(s[1].end.x - edge) <= 1.0) and s[1].size.y >= bounds.size.y * 0.5)
        if not walled:
            issues.append(_issue("info", "open_side", path, 0, "The %s side of the level (x = %.0f) has no tall wall; players may walk or jump out." % [side, edge], "Add a wall, a camera/level limit with a blocker, or a kill zone beyond the edge."))
    for k in kills:
        for s in solids:
            var top := Rect2(s[1].position.x, s[1].position.y - 2.0, s[1].size.x, 4.0)
            if k[1].intersects(top):
                issues.append(_issue("warning", "kill_zone_overlap", path, k[0]["line"], "%s overlaps the top of %s; players standing there would die." % [k[0]["name"], s[0]["name"]], "Move the kill zone below the floor surface."))
    return _finish({"solids": solids.size(), "kill_zones": kills.size(), "level_bounds": [bounds.position.x, bounds.position.y, bounds.end.x, bounds.end.y]}, issues)


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
    var lines: Array = ["# World Boundary and Out-of-Bounds Auditor", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
