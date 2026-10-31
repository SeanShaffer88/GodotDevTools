## Level Design Whiteboxing and Snapping Suite - grid operation.
## The blockout maths, pure: snap a position to a grid (whole cells or
## subdivisions), snap a rotation to a step, and judge whether the slope
## between two walk points is walkable. scan_scene() reads a Node3D
## scene's text and checks every transform against the grid config:
## props floating between cells, ramps steeper than the character
## controller can climb, and markers that drifted from their intended
## cell by less than a snap but more than tolerance. The dock applies
## snapping to selected nodes in the live editor (that half needs the
## editor, and is marked as such in docs/PARITY.md); this file is the
## checkable half that runs headless on any scene text.
extends RefCounted

var grid: float = 1.0
var subdivisions: int = 1
var max_slope_degrees: float = 45.0
var tolerance: float = 0.02


func snap_position(pos: Vector3, grid_step: float = -1.0, subdivide: int = -1) -> Vector3:
    var step := grid_step if grid_step > 0.0 else grid / float(subdivide if subdivide > 0 else subdivisions)
    step = maxf(step, 0.000001)
    return Vector3(roundf(pos.x / step) * step, roundf(pos.y / step) * step, roundf(pos.z / step) * step)


func snap_rotation(degrees: float, step_degrees: float = 15.0) -> float:
    var step := maxf(step_degrees, 0.000001)
    return roundf(degrees / step) * step


## Slope angle (degrees) between two walk points, from the horizontal
## distance and the height difference.
func slope_degrees(a: Vector3, b: Vector3) -> float:
    var horizontal := Vector2(b.x - a.x, b.z - a.z).length()
    var rise := absf(b.y - a.y)
    if horizontal < 0.000001:
        return 90.0 if rise > 0.000001 else 0.0
    return rad_to_deg(atan2(rise, horizontal))


## Parse Node3D-family transforms out of a scene's text:
## [{name, type, parent, origin}].
func parse_scene(text: String) -> Array:
    var out: Array = []
    var current: Dictionary = {}
    for raw in text.split("\n"):
        var line := raw.strip_edges()
        if line.begins_with("[node "):
            if not current.is_empty():
                out.append(current)
            current = {"name": _attr(line, "name"), "type": _attr(line, "type"),
                "parent": _attr(line, "parent"), "origin": null}
        elif line.begins_with("["):
            if not current.is_empty():
                out.append(current)
            current = {}
        elif not current.is_empty() and line.begins_with("transform = Transform3D("):
            var inner := line.trim_prefix("transform = Transform3D(").trim_suffix(")")
            var parts := inner.split(",")
            if parts.size() >= 12:
                current["origin"] = Vector3(float(parts[9]), float(parts[10]), float(parts[11]))
    if not current.is_empty():
        out.append(current)
    return out


func _attr(line: String, key: String) -> String:
    var marker := key + "=\""
    var i := line.find(marker)
    if i < 0:
        return ""
    var rest := line.substr(i + marker.length())
    return rest.substr(0, rest.find("\""))


## The one operation: check a parsed scene's nodes against the grid and
## slope rules. Walk paths are nodes under a parent named like
## "WalkPath*" in file order.
func run(nodes: Array, config: Dictionary = {}) -> Dictionary:
    if config.has("grid"):
        grid = float(config["grid"])
    if config.has("subdivisions"):
        subdivisions = int(config["subdivisions"])
    if config.has("max_slope_degrees"):
        max_slope_degrees = float(config["max_slope_degrees"])
    if config.has("tolerance"):
        tolerance = float(config["tolerance"])
    var issues: Array = []
    var off_grid := 0
    var walk_points: Array = []
    for n in nodes:
        var node: Dictionary = n
        if node["origin"] == null:
            continue
        var origin: Vector3 = node["origin"]
        var step := grid / float(maxi(subdivisions, 1))
        for axis in ["x", "y", "z"]:
            var v: float = origin[axis]
            var nearest := roundf(v / step) * step
            var drift := absf(v - nearest)
            if drift > tolerance:
                off_grid += 1
                issues.append({"severity": "warning", "kind": "off_grid", "path": str(node["name"]),
                    "message": "'%s' sits %s=%.3f - %.3f off the %.2f grid; blockouts drift like this until doors stop sealing and floors show seams." % [
                        node["name"], axis, v, drift, step],
                    "fix": "Snap it: position becomes %s." % str(snap_position(origin))})
                break
        if str(node["parent"]).to_lower().begins_with("walkpath"):
            walk_points.append(node)
    for i in range(1, walk_points.size()):
        var a: Vector3 = (walk_points[i - 1] as Dictionary)["origin"]
        var b: Vector3 = (walk_points[i] as Dictionary)["origin"]
        var degrees := slope_degrees(a, b)
        if degrees > max_slope_degrees:
            issues.append({"severity": "error", "kind": "steep_slope", "path": str((walk_points[i] as Dictionary)["name"]),
                "message": "Walk path '%s' -> '%s' climbs %.1f degrees (limit %.1f) - the character controller will not climb it." % [
                    (walk_points[i - 1] as Dictionary)["name"], (walk_points[i] as Dictionary)["name"],
                    degrees, max_slope_degrees],
                "fix": "Lengthen the run or add a step; a 4:1 ramp (about 14 degrees) is the comfortable blockout default."})
    return {"summary": {"nodes": nodes.size(), "off_grid": off_grid,
            "walk_points": walk_points.size(), "issues": issues.size()},
        "issues": issues}


func to_json(result: Dictionary) -> String:
    return JSON.stringify({"summary": result["summary"], "issues": result["issues"]}, "\t")


func to_markdown(result: Dictionary) -> String:
    var s: Dictionary = result["summary"]
    var lines: Array[String] = ["# Whitebox Report", "",
        "%d nodes, %d off-grid, %d walk points. %d problems." % [
            s["nodes"], s["off_grid"], s["walk_points"], s["issues"]], ""]
    for i in result["issues"]:
        lines.append("- [%s] %s" % [i["severity"], i["message"]])
    return "\n".join(lines) + "\n"
