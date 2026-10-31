## Physics Collision Matrix Visualizer - matrix operation.
## Reads the project's named physics layers and every collision_layer /
## collision_mask value in the project's scene text, then builds the
## who-collides-with-whom matrix: for each declared layer bit, which
## mask bits query it and how many candidate pairs that produces. The
## report flags the accidents this data reveals - bodies set to collide
## with everything, raycasts carrying a layer they will never need,
## layer bits nobody queries, mask bits nobody declares, and bits in
## use with no name. Pure text + bit maths; live in-game counters are
## the runtime node's job, not this file's.
extends RefCounted

## A mask (or layer) with at least this many bits set counts as
## all-vs-all: at 32 bits wide, half the world is an accident.
var all_vs_all_bits: int = 16
const RAY_TYPES: Array[String] = ["RayCast2D", "RayCast3D", "ShapeCast2D", "ShapeCast3D"]


func popcount(value: int) -> int:
    var v := value
    var n := 0
    while v != 0:
        n += v & 1
        v = v >> 1  # Godot ints are 64-bit two's complement; masks are 32-bit positive
    return n


func layer_names() -> Dictionary:
    var out: Dictionary = {}
    for i in 32:
        var key := "layer_names/2d_physics/layer_%d" % (i + 1)
        var key3 := "layer_names/3d_physics/layer_%d" % (i + 1)
        var n := str(ProjectSettings.get_setting(key, ""))
        if n == "":
            n = str(ProjectSettings.get_setting(key3, ""))
        if n != "":
            out[i] = n
    return out


func find_scenes() -> Array:
    var out: Array = []
    _walk("res://", out)
    return out


func _walk(dir_path: String, out: Array) -> void:
    var dir := DirAccess.open(dir_path)
    if dir == null:
        return
    dir.list_dir_begin()
    var name := dir.get_next()
    while name != "":
        if name.begins_with("."):
            name = dir.get_next()
            continue
        var full := dir_path.path_join(name)
        if dir.current_is_dir():
            if name not in [".godot", "addons"]:
                _walk(full, out)
        elif name.get_extension() == "tscn":
            out.append(full)
        name = dir.get_next()
    dir.list_dir_end()


## Parse collision properties out of one scene's text.
func parse_scene(text: String, path: String) -> Array:
    var bodies: Array = []
    var current: Dictionary = {}
    for raw in text.split("\n"):
        var line := raw.strip_edges()
        if line.begins_with("[node "):
            if not current.is_empty():
                bodies.append(current)
            current = {"name": _attr(line, "name"), "type": _attr(line, "type"),
                "path": path, "layer": -1, "mask": -1}
        elif line.begins_with("["):
            if not current.is_empty():
                bodies.append(current)
            current = {}
        elif not current.is_empty():
            if line.begins_with("collision_layer = "):
                current["layer"] = int(line.trim_prefix("collision_layer = "))
            elif line.begins_with("collision_mask = "):
                current["mask"] = int(line.trim_prefix("collision_mask = "))
    if not current.is_empty():
        bodies.append(current)
    var out: Array = []
    for b in bodies:
        if int(b["layer"]) >= 0 or int(b["mask"]) >= 0:
            out.append(b)
    return out


func _attr(line: String, key: String) -> String:
    var marker := key + "=\""
    var i := line.find(marker)
    if i < 0:
        return ""
    var rest := line.substr(i + marker.length())
    return rest.substr(0, rest.find("\""))


func collect() -> Array:
    var bodies: Array = []
    for path in find_scenes():
        var text := FileAccess.get_file_as_string(str(path))
        if text != "":
            bodies.append_array(parse_scene(text, str(path)))
    return bodies


## The one operation: build the matrix and the issue list from body
## records ([{name, type, path, layer, mask}]) and layer names.
func analyze(bodies: Array, names: Dictionary) -> Dictionary:
    var issues: Array = []
    var layer_nodes: Dictionary = {}
    var mask_nodes: Dictionary = {}
    for b in bodies:
        var layer: int = int(b["layer"]) if int(b["layer"]) >= 0 else 1
        var mask: int = int(b["mask"]) if int(b["mask"]) >= 0 else 1
        for bit in 32:
            if (layer >> bit) & 1:
                layer_nodes[bit] = int(layer_nodes.get(bit, 0)) + 1
            if (mask >> bit) & 1:
                mask_nodes[bit] = int(mask_nodes.get(bit, 0)) + 1
        if popcount(mask) >= all_vs_all_bits:
            issues.append({"severity": "error", "kind": "all_vs_all", "path": str(b["path"]),
                "message": "'%s' in %s masks %d layers at once - it checks collision against practically everything, every physics frame." % [b["name"], b["path"], popcount(mask)],
                "fix": "Mask only the layers this body must react to; broad 'touch everything' masks are the usual source of surprise interactions and physics cost."})
        if str(b["type"]) in RAY_TYPES and int(b["layer"]) > 0:
            issues.append({"severity": "warning", "kind": "redundant_raycast_layer", "path": str(b["path"]),
                "message": "Raycast '%s' in %s sits on collision layer %d; raycasts query with their mask and are never hit by others." % [b["name"], b["path"], int(b["layer"])],
                "fix": "Set the raycast's collision_layer to 0 and keep only the mask."})
    var matrix: Dictionary = {}
    var pair_total := 0
    for layer_bit in layer_nodes:
        for mask_bit in mask_nodes:
            if layer_bit == mask_bit:
                var pairs: int = int(layer_nodes[layer_bit]) * int(mask_nodes[mask_bit])
                matrix[layer_bit] = pairs
                pair_total += pairs
    for bit in 32:
        var declared: int = int(layer_nodes.get(bit, 0))
        var queried: int = int(mask_nodes.get(bit, 0))
        if declared > 0 and queried == 0:
            issues.append({"severity": "info", "kind": "unused_layer", "path": "",
                "message": "Layer bit %d (%s) is declared by %d node(s) but no mask ever queries it." % [bit + 1, str(names.get(bit, "unnamed")), declared],
                "fix": "Either something should mask this layer, or the nodes do not need to be on it."})
        if queried > 0 and declared == 0:
            issues.append({"severity": "info", "kind": "dead_mask", "path": "",
                "message": "Mask bit %d (%s) is queried by %d node(s) but nothing declares that layer - those checks can never hit." % [bit + 1, str(names.get(bit, "unnamed")), queried],
                "fix": "Put the intended targets on this layer, or clear the bit from the masks."})
        if (declared > 0 or queried > 0) and not names.has(bit):
            issues.append({"severity": "info", "kind": "unnamed_layer", "path": "",
                "message": "Physics layer bit %d is in use but has no name in Project Settings." % (bit + 1),
                "fix": "Name it under Project Settings -> Layer Names so the matrix stays readable."})
    return {"summary": {"bodies": bodies.size(), "layer_bits": layer_nodes.size(),
            "mask_bits": mask_nodes.size(), "candidate_pairs": pair_total,
            "issues": issues.size()},
        "matrix": matrix, "issues": issues}


func run() -> Dictionary:
    return analyze(collect(), layer_names())


func to_json(result: Dictionary) -> String:
    return JSON.stringify({"summary": result["summary"], "issues": result["issues"],
        "matrix": result.get("matrix", {})}, "\t")


func to_markdown(result: Dictionary) -> String:
    var s: Dictionary = result["summary"]
    var lines: Array[String] = ["# Collision Matrix Report", "",
        "%d physics bodies, %d layer bits declared, %d mask bits queried, %d candidate pair combinations. %d problems." % [
            s["bodies"], s["layer_bits"], s["mask_bits"], s["candidate_pairs"], s["issues"]], ""]
    for i in result["issues"]:
        lines.append("- [%s] %s" % [i["severity"], i["message"]])
    return "\n".join(lines) + "\n"
