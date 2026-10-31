## Navigation Mesh Diagnostic Lab - 2D navmesh analysis.
## Reads the baked vertices and polygons of a NavigationPolygon. Polygons
## sharing an edge are connected; connected components are regions, and
## regions other than the largest are reported. Shared edges shorter than
## the agent's diameter are narrow passages the agent cannot fit through.
## With a targets file, each target is located on the mesh and checked for
## reachability from the start point. Coordinates are the navmesh's local
## space (the NavigationRegion2D at the origin, unrotated, unscaled).
extends RefCounted

const EXTS: Array[String] = ["tres", "tscn"]
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

const DEFAULTS := {"targets": ""}


func run(input: String = "", options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    if not FileAccess.file_exists(input):
        return _fail(input, "Navmesh file not found.", "Pass --nav=<.tres with a baked NavigationPolygon>.", "bad_input")
    var targets := {}
    if str(opts["targets"]) != "":
        var t: Variant = _read_json(str(opts["targets"]))
        if typeof(t) != TYPE_DICTIONARY:
            return _fail(str(opts["targets"]), "Targets file missing or not a JSON object.", "See the README for the format.", "bad_input")
        targets = t
    return evaluate(parse_nav(FileAccess.get_file_as_string(input)), targets, input)


func evaluate(nav: Dictionary, targets: Dictionary = {}, path: String = "") -> Dictionary:
    var issues: Array = []
    if nav["polygons"].is_empty():
        issues.append(_issue("error", "no_navmesh", path, 0, "No baked polygons found.", "Bake the NavigationPolygon in the editor and save the resource."))
        return _finish({"polygons": 0, "regions": 0}, issues)
    var adj := adjacency(nav)
    var comp := components(adj)
    var sizes := {}
    for i in comp.keys():
        var area := absf(_area(poly_points(nav, i)))
        sizes[comp[i]] = float(sizes.get(comp[i], 0.0)) + area
    var main := 0
    for c in sizes.keys():
        if float(sizes[c]) > float(sizes[main]):
            main = c
    for c in sizes.keys():
        if c != main:
            var first := -1
            for i in comp.keys():
                if comp[i] == c and first < 0:
                    first = i
            var centre := Vector2.ZERO
            for p in poly_points(nav, first):
                centre += p
            centre /= poly_points(nav, first).size()
            issues.append(_issue("warning", "disconnected_region", path, 0, "Region of %.0f square units around %s is not connected to the main mesh." % [sizes[c], centre], "Connect it (overlap or snap the outlines) or confirm it is reached by teleport/jump links."))
    var radius := float(targets.get("agent_radius", 0.0))
    if radius > 0.0:
        var seen := {}
        for i in adj.keys():
            for j in adj[i].keys():
                var key := "%d_%d" % [min(i, j), max(i, j)]
                if seen.has(key):
                    continue
                seen[key] = true
                if float(adj[i][j]) < radius * 2.0:
                    issues.append(_issue("warning", "narrow_passage", path, 0, "Polygons %d and %d connect through an edge %.1f long; an agent of radius %.1f needs %.1f." % [i, j, adj[i][j], radius, radius * 2.0], "Widen the passage, or bake with the agent radius so paths avoid it."))
    var results: Array = []
    if targets.has("start"):
        var start := Vector2(float(targets["start"][0]), float(targets["start"][1]))
        var sp := locate(nav, start)
        for t in targets.get("targets", []):
            var p := Vector2(float(t["pos"][0]), float(t["pos"][1]))
            var tp := locate(nav, p)
            var ok: bool = sp >= 0 and tp >= 0 and comp[sp] == comp[tp]
            results.append({"id": t.get("id", "?"), "polygon": tp, "reachable": ok})
            if tp < 0:
                issues.append(_issue("warning", "off_mesh_point", path, 0, "Target %s at %s is not on the navmesh." % [t.get("id", "?"), p], "Move it onto walkable space or extend the mesh."))
            elif not ok:
                issues.append(_issue("error", "unreachable_target", path, 0, "Target %s at %s cannot be reached from the start %s." % [t.get("id", "?"), p, start], "Connect its region to the start region."))
    return _finish({"polygons": nav["polygons"].size(), "regions": sizes.size()}, issues, {"targets": results})


func _area(pts: PackedVector2Array) -> float:
    var a := 0.0
    for k in range(pts.size()):
        a += pts[k].cross(pts[(k + 1) % pts.size()])
    return a / 2.0


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
    var lines: Array = ["# Navigation Mesh Diagnostic Lab", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
