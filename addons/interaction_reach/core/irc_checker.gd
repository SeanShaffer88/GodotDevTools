## Interaction Reachability Checker - can the player get there?
## Interactables are Area2D nodes in a group, or with a name, containing the
## pattern. An interactable is reachable when some point of its trigger
## shape (centre or the 8 points around its radius/extent) lies on a navmesh
## polygon connected to the player's start polygon.
extends RefCounted

const EXTS: Array[String] = ["tscn"]
## NavigationPolygon text -> {"vertices": [Vector2], "polygons": [[int]]} (empty when not found).
func parse_nav(text: String) -> Dictionary:
    var verts: Array = []
    var polys: Array = []
    for raw in text.split("\n"):
        var s := raw.strip_edges()
        if s.begins_with("vertices = PackedVector2Array("):
            var nums := s.get_slice("(", 1).get_slice(")", 0).split(",", false)
            for k in range(0, nums.size() - 1, 2):
                verts.append(Vector2(float(nums[k]), float(nums[k + 1])))
        elif s.begins_with("polygons = "):
            for m in RegEx.create_from_string("PackedInt32Array\\(([^)]*)\\)").search_all(s):
                polys.append(Array(m.get_string(1).split(",", false)).map(func(x): return int(x)))
    return {"vertices": verts, "polygons": polys}


func poly_points(nav: Dictionary, i: int) -> PackedVector2Array:
    var pts := PackedVector2Array()
    for v in nav["polygons"][i]:
        pts.append(nav["vertices"][v])
    return pts


## Index of the polygon containing p, or -1.
func locate(nav: Dictionary, p: Vector2) -> int:
    for i in range(nav["polygons"].size()):
        if Geometry2D.is_point_in_polygon(p, poly_points(nav, i)):
            return i
    return -1


## Polygons sharing an edge (two consecutive vertex indices) are adjacent: {i: {j: edge_length}}.
func adjacency(nav: Dictionary) -> Dictionary:
    var edges := {}
    var adj := {}
    for i in range(nav["polygons"].size()):
        adj[i] = {}
        var p: Array = nav["polygons"][i]
        for k in range(p.size()):
            var a: int = p[k]
            var b: int = p[(k + 1) % p.size()]
            var key := "%d_%d" % [min(a, b), max(a, b)]
            if edges.has(key):
                var j: int = edges[key]
                var length: float = nav["vertices"][a].distance_to(nav["vertices"][b])
                adj[i][j] = length
                adj[j][i] = length
            else:
                edges[key] = i
    return adj


## Component id per polygon.
func components(adj: Dictionary) -> Dictionary:
    var comp := {}
    var next := 0
    for start in adj.keys():
        if comp.has(start):
            continue
        var stack: Array = [start]
        while not stack.is_empty():
            var n: int = stack.pop_back()
            if comp.has(n):
                continue
            comp[n] = next
            for m in adj[n].keys():
                stack.append(m)
        next += 1
    return comp

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

const DEFAULTS := {"nav": "", "start": "", "pattern": "interact"}


func run(input: String = "", options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    if not FileAccess.file_exists(input):
        return _fail(input, "Scene not found.", "Pass --scene=<level .tscn>.", "bad_input")
    if str(opts["nav"]) == "":
        return _fail(input, "A navmesh is required.", "Pass --nav=<baked NavigationPolygon .tres>.", "bad_input")

    var nav := {}
    if str(opts["nav"]) != "":
        if not FileAccess.file_exists(str(opts["nav"])):
            return _fail(str(opts["nav"]), "Navigation polygon resource not found.", "Pass a .tres holding a baked NavigationPolygon.", "bad_input")
        nav = parse_nav(FileAccess.get_file_as_string(str(opts["nav"])))

    return evaluate(parse_2d(FileAccess.get_file_as_string(input)), nav, opts, input)


func evaluate(scene: Dictionary, nav: Dictionary, options: Dictionary = {}, path: String = "") -> Dictionary:
    var opts := _opts(options)
    var issues: Array = []
    var start := Vector2.ZERO
    if str(opts["start"]) != "":
        var xy := str(opts["start"]).split(",")
        start = Vector2(float(xy[0]), float(xy[1]))
    else:
        for n in scene["nodes"]:
            if str(n["name"]).to_lower() in ["player", "start", "playerstart"] or n["groups"].has("player"):
                start = n["pos"]
                break
    var comp := components(adjacency(nav))
    var sp := locate(nav, start)
    var pat := str(opts["pattern"]).to_lower()
    var items: Array = scene["nodes"].filter(func(n): return n["type"] == "Area2D" and (n["groups"].any(func(g): return str(g).to_lower().contains(pat)) or str(n["name"]).to_lower().contains(pat)))
    if items.is_empty():
        issues.append(_issue("info", "no_interactables", path, 0, "No interactables found (Area2D in a group or with a name containing '%s')." % pat, "Use an 'interactable' group or pass --pattern."))
        return _finish({"interactables": 0}, issues)
    var reachable := 0
    for it in items:
        var rect := Rect2(it["pos"], Vector2.ZERO)
        for sh in children_of(scene, it["path"]):
            if str(sh["type"]) == "CollisionShape2D":
                rect = rect.merge(shape_rect(scene, sh)) if shape_rect(scene, sh).has_area() else rect
        var probes: Array = [rect.get_center(), rect.position, rect.end, Vector2(rect.position.x, rect.end.y), Vector2(rect.end.x, rect.position.y),
            Vector2(rect.get_center().x, rect.position.y), Vector2(rect.get_center().x, rect.end.y), Vector2(rect.position.x, rect.get_center().y), Vector2(rect.end.x, rect.get_center().y)]
        var ok := false
        for p in probes:
            var poly := locate(nav, p)
            if sp >= 0 and poly >= 0 and comp[poly] == comp[sp]:
                ok = true
                break
        if ok:
            reachable += 1
        else:
            issues.append(_issue("error", "unreachable_interactable", path, it["line"], "%s at %s: no walkable point inside its trigger is reachable from the start %s." % [it["name"], it["pos"], start], "Move it next to walkable space connected to the start, or connect its region."))
    return _finish({"interactables": items.size(), "reachable": reachable}, issues)


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
    var lines: Array = ["# Interaction Reachability Checker", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
