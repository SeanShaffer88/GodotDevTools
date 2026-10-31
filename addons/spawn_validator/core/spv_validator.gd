## Spawn Point and Encounter Validator - 2D spawn checks.
## Spawn points are nodes in a group, or with a name, containing the spawn
## pattern. Each is checked against the rectangles/circles of StaticBody2D
## collision shapes (translation only), against other spawns for minimum
## spacing, and optionally against a baked navmesh. Positions combine parent
## translations; rotation and scale are ignored.
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

const DEFAULTS := {"min_spacing": 32.0, "spawn_pattern": "spawn", "nav": ""}


func run(input: String = "", options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    if not FileAccess.file_exists(input):
        return _fail(input, "Scene not found.", "Pass --scene=<level .tscn>.", "bad_input")

    var nav := {}
    if str(opts["nav"]) != "":
        if not FileAccess.file_exists(str(opts["nav"])):
            return _fail(str(opts["nav"]), "Navigation polygon resource not found.", "Pass a .tres holding a baked NavigationPolygon.", "bad_input")
        nav = parse_nav(FileAccess.get_file_as_string(str(opts["nav"])))

    return evaluate(parse_2d(FileAccess.get_file_as_string(input)), nav, opts, input)


func evaluate(scene: Dictionary, nav: Dictionary, options: Dictionary = {}, path: String = "") -> Dictionary:
    var opts := _opts(options)
    var pat := str(opts["spawn_pattern"]).to_lower()
    var spawns: Array = scene["nodes"].filter(func(n): return n["groups"].any(func(g): return str(g).to_lower().contains(pat)) or str(n["name"]).to_lower().contains(pat))
    var issues: Array = []
    if spawns.is_empty():
        issues.append(_issue("info", "no_spawns", path, 0, "No spawn points found (group or name containing '%s')." % pat, "Put spawn markers in a 'spawn' group or pass --spawn-pattern."))
        return _finish({"spawns": 0}, issues)
    var solids: Array = []
    for body in scene["nodes"].filter(func(n): return n["type"] in ["StaticBody2D", "AnimatableBody2D"]):
        for sh in children_of(scene, body["path"]):
            if str(sh["type"]) == "CollisionShape2D":
                var r := shape_rect(scene, sh)
                if r.has_area():
                    solids.append([body["name"], r])
    for s in spawns:
        for solid in solids:
            if solid[1].has_point(s["pos"]):
                issues.append(_issue("error", "blocked_spawn", path, s["line"], "%s at %s is inside %s." % [s["name"], s["pos"], solid[0]], "Move the spawn into open space."))
        if not nav.is_empty() and locate(nav, s["pos"]) < 0:
            issues.append(_issue("warning", "off_nav_spawn", path, s["line"], "%s at %s is not on the navmesh; agents spawned there cannot path." % [s["name"], s["pos"]], "Move it onto the navmesh or extend the mesh."))
    for a in range(spawns.size()):
        for b in range(a + 1, spawns.size()):
            var d: float = spawns[a]["pos"].distance_to(spawns[b]["pos"])
            if d < float(opts["min_spacing"]):
                issues.append(_issue("warning", "crowded_spawns", path, spawns[b]["line"], "%s and %s are %.1f apart (minimum %.1f)." % [spawns[a]["name"], spawns[b]["name"], d, opts["min_spacing"]], "Spread them out so simultaneous spawns do not overlap."))
    return _finish({"spawns": spawns.size(), "solids": solids.size()}, issues)


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
    var lines: Array = ["# Spawn Point and Encounter Validator", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
