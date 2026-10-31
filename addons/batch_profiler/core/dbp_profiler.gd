## Draw-Call and Batching Profiler - scene risk operation.
## Godot 4 does not batch 2D the way Godot 3 did, but draw calls are
## still multiplied by the same mistakes: siblings alternating materials,
## z_index values that interleave instead of grouping, and lights that
## add a shaded pass over the items they touch. This operation reads
## scene text (no renderer, no editor APIs), walks every CanvasItem in
## draw order per parent, and reports each pattern with a plain-words
## fix, so the question "why is this scene expensive to draw?" gets an
## answer from the data alone. Live draw-call counts need a real
## renderer; this is the static half.
extends RefCounted

## Node types treated as drawable canvas items when scanning scene text.
const DRAWABLE_TYPES: Array[String] = ["Sprite2D", "Label", "ColorRect", "TextureRect",
    "Control", "Node2D", "Polygon2D", "Line2D", "RichTextLabel", "Button", "Panel"]
const LIGHT_TYPES: Array[String] = ["PointLight2D", "DirectionalLight2D", "Light2D"]
## A z sequence that changes direction (up then down, or down then up)
## interleaves items that could otherwise stay in one sorted run.
var skip_addons: bool = true


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


## Parse one scene's text into [{name, type, parent, material, z_index,
## light_mode}] in file order, which for siblings is draw order.
func parse_scene(text: String) -> Array:
    var nodes: Array = []
    var current: Dictionary = {}
    for raw in text.split("\n"):
        var line := raw.strip_edges()
        if line.begins_with("[node "):
            if not current.is_empty():
                nodes.append(current)
            current = {"name": _attr(line, "name"), "type": _attr(line, "type"),
                "parent": _attr(line, "parent"), "material": "", "z_index": 0,
                "light_mode": -1}
        elif line.begins_with("[") and not line.begins_with("[node"):
            if not current.is_empty():
                nodes.append(current)
            current = {}
        elif not current.is_empty():
            if line.begins_with("material = "):
                current["material"] = line.trim_prefix("material = ")
            elif line.begins_with("z_index = "):
                current["z_index"] = int(line.trim_prefix("z_index = "))
            elif line.begins_with("light_mode = "):
                current["light_mode"] = int(line.trim_prefix("light_mode = "))
    if not current.is_empty():
        nodes.append(current)
    return nodes


func _attr(line: String, key: String) -> String:
    var marker := key + "=\""
    var i := line.find(marker)
    if i < 0:
        return ""
    var rest := line.substr(i + marker.length())
    return rest.substr(0, rest.find("\""))


## The one operation: scan every scene (or one scene's text) and report
## draw-call risk findings.
func run(scene_text: String = "", scene_path: String = "") -> Dictionary:
    var issues: Array = []
    var scenes_checked := 0
    var items_seen := 0
    if scene_text != "":
        scenes_checked = 1
        items_seen += _check_scene(scene_path, parse_scene(scene_text), issues)
    else:
        for path in find_scenes():
            var text := FileAccess.get_file_as_string(str(path))
            if text == "":
                continue
            scenes_checked += 1
            items_seen += _check_scene(str(path), parse_scene(text), issues)
    var material_switches := 0
    var z_interleaves := 0
    var light_passes := 0
    for i in issues:
        match str(i["kind"]):
            "material_switch": material_switches += 1
            "z_interleave": z_interleaves += 1
            "light_pass": light_passes += 1
    return {"summary": {"scenes": scenes_checked, "canvas_items": items_seen,
            "material_switches": material_switches, "z_interleaves": z_interleaves,
            "light_passes": light_passes, "issues": issues.size()},
        "issues": issues}


func _check_scene(path: String, nodes: Array, issues: Array) -> int:
    var by_parent: Dictionary = {}
    var lights := 0
    for n in nodes:
        if str(n["type"]) in LIGHT_TYPES:
            lights += 1
        if not (str(n["type"]) in DRAWABLE_TYPES):
            continue
        var parent := str(n["parent"])
        if not by_parent.has(parent):
            by_parent[parent] = []
        (by_parent[parent] as Array).append(n)
    var items := 0
    for parent in by_parent:
        var siblings: Array = by_parent[parent]
        items += siblings.size()
        _check_materials(path, str(parent), siblings, issues)
        _check_z(path, str(parent), siblings, issues)
    if lights > 0:
        var shaded := 0
        for n in nodes:
            if str(n["type"]) in DRAWABLE_TYPES and int(n["light_mode"]) != 1:
                shaded += 1
        if shaded > 0:
            issues.append({"severity": "warning", "kind": "light_pass", "path": path,
                "message": "%s has %d Light2D node(s) over %d shaded item(s); every light adds a pass over what it touches." % [path, lights, shaded],
                "fix": "Set light_mode to Unshaded on items that need no lighting, or cull the light's range so it touches fewer items."})
    return items


func _check_materials(path: String, parent: String, siblings: Array, issues: Array) -> void:
    var last := ""
    var switches := 0
    for n in siblings:
        var mat := str(n["material"])
        if mat == "":
            continue
        if last != "" and mat != last:
            switches += 1
        last = mat
    if switches >= 2:
        issues.append({"severity": "warning", "kind": "material_switch", "path": path,
            "message": "Children of '%s' in %s switch material %d times in draw order; each switch can end a merged draw." % [parent if parent != "" else "(root)", path, switches],
            "fix": "Group same-material siblings together (reorder children or use a shared parent), or share one material resource between them."})


func _check_z(path: String, parent: String, siblings: Array, issues: Array) -> void:
    var seq: Array = []
    for n in siblings:
        seq.append(int(n["z_index"]))
    var rises := false
    var falls := false
    for i in range(1, seq.size()):
        if int(seq[i]) > int(seq[i - 1]):
            rises = true
        elif int(seq[i]) < int(seq[i - 1]):
            falls = true
    if rises and falls:
        issues.append({"severity": "warning", "kind": "z_interleave", "path": path,
            "message": "Children of '%s' in %s interleave z_index up and down (%s); the renderer must split them into separate sorted runs." % [parent if parent != "" else "(root)", path, str(seq)],
            "fix": "Give interleaved items one shared z_index and order them by child position, or move background/foreground groups under their own parents."})


func to_json(result: Dictionary) -> String:
    return JSON.stringify({"summary": result["summary"], "issues": result["issues"]}, "\t")


func to_markdown(result: Dictionary) -> String:
    var s: Dictionary = result["summary"]
    var lines: Array[String] = ["# Draw-Call Risk Report", "",
        "%d scenes, %d canvas items: %d material switches, %d z interleave cases, %d light passes." % [
            s["scenes"], s["canvas_items"], s["material_switches"], s["z_interleaves"], s["light_passes"]], ""]
    for i in result["issues"]:
        lines.append("- [%s] %s" % [i["severity"], i["message"]])
    return "\n".join(lines) + "\n"
