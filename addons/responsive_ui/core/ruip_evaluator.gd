## Responsive UI Previewer - layout evaluation operation.
## Works out, for each target screen size, how a UI scene will actually
## be laid out under the project's stretch settings: the visible content
## area after stretch + aspect handling, the area left after a simulated
## safe-area inset (phone notch / rounded corners), and whether any
## Control in the scene would land outside that area or below a usable
## minimum size. Scene files are read as text (offsets/sizes/anchors),
## so the check runs headless and in CI - no editor needed.
extends RefCounted

var min_control_size: float = 24.0 ## Smallest usable touch/click target.
var viewports: Array[Dictionary] = [
    {"name": "Desktop FHD", "size": Vector2i(1920, 1080), "safe": Rect2i(0, 0, 1920, 1080)},
    {"name": "Laptop", "size": Vector2i(1280, 720), "safe": Rect2i(0, 0, 1280, 720)},
    {"name": "Project base", "size": Vector2i(1152, 648), "safe": Rect2i(0, 0, 1152, 648)},
    {"name": "Small window", "size": Vector2i(800, 600), "safe": Rect2i(0, 0, 800, 600)},
    {"name": "Phone landscape (notch)", "size": Vector2i(844, 390), "safe": Rect2i(47, 0, 750, 390)},
    {"name": "Phone portrait (notch)", "size": Vector2i(390, 844), "safe": Rect2i(0, 47, 390, 763)},
    {"name": "Tablet", "size": Vector2i(1024, 768), "safe": Rect2i(0, 0, 1024, 768)},
    {"name": "Ultrawide", "size": Vector2i(2560, 1080), "safe": Rect2i(0, 0, 2560, 1080)},
    {"name": "Steam Deck", "size": Vector2i(1280, 800), "safe": Rect2i(0, 0, 1280, 800)},
]


## The content area (in viewport pixels) that the base-size UI occupies
## for a target size, given stretch mode + aspect from project settings.
func content_rect(base: Vector2, target: Vector2i, stretch_mode: String, aspect: String) -> Rect2:
    if stretch_mode == "disabled":
        return Rect2(Vector2.ZERO, base)
    var scale_factor := 1.0
    var sx := float(target.x) / base.x
    var sy := float(target.y) / base.y
    match aspect:
        "keep": scale_factor = minf(sx, sy)
        "keep_width": scale_factor = sx
        "keep_height": scale_factor = sy
        "expand": return Rect2(Vector2.ZERO, Vector2(target))
        _: scale_factor = minf(sx, sy) # ignore -> fit
    var content := Vector2(base.x * scale_factor, base.y * scale_factor)
    return Rect2((Vector2(target) - content) * 0.5, content)


## Evaluate one parsed control at one viewport.
## control: {name, path, rect: Rect2 (base-size pixels), anchors_full: bool}
func evaluate_control(control: Dictionary, base: Vector2, vp: Dictionary, stretch_mode: String, aspect: String) -> Array:
    var issues: Array = []
    var target: Vector2i = vp["size"]
    var safe: Rect2i = vp["safe"]
    var area := content_rect(base, target, stretch_mode, aspect)
    var r: Rect2 = control["rect"]
    var mapped: Rect2
    if bool(control.get("anchors_full", false)):
        mapped = Rect2(area.position, area.size)
    else:
        var kx := area.size.x / base.x
        var ky := area.size.y / base.y
        mapped = Rect2(area.position + Vector2(r.position.x * kx, r.position.y * ky),
            Vector2(r.size.x * kx, r.size.y * ky))
    var safe_f := Rect2(safe)
    if not safe_f.encloses(mapped):
        issues.append({"severity": "warning", "kind": "outside_safe_area", "path": control["path"],
            "message": "%s: '%s' lands at %s on %s - outside the safe area %s (stretch: %s/%s)." % [
                vp["name"], control["name"], str(mapped), vp["name"], str(safe_f), stretch_mode, aspect],
            "fix": "Anchor this control to the safe side, move it inside the safe area, or use a SafeArea-style margin container."})
    if mapped.size.x < min_control_size or mapped.size.y < min_control_size:
        issues.append({"severity": "warning", "kind": "target_too_small", "path": control["path"],
            "message": "%s: '%s' shrinks to %s - below the %.0f px usable target size." % [
                vp["name"], control["name"], str(mapped.size), min_control_size],
            "fix": "Give the control a larger minimum size, or let the layout scale it up on small screens."})
    return issues


func _parse_controls(path: String, text: String) -> Array:
    var controls: Array = []
    var current: Dictionary = {}
    var name_re := RegEx.new()
    name_re.compile("^\\[node name=\"([^\"]+)\"")
    for line in text.split("\n"):
        var m := name_re.search(line)
        if m != null:
            if not current.is_empty():
                controls.append(current)
            current = {"name": m.get_string(1), "path": path, "rect": Rect2(0, 0, 100, 30), "anchors_full": false,
                "_ox": 0.0, "_oy": 0.0, "_sx": 100.0, "_sy": 30.0, "_ax": 0.0, "_ay": 0.0}
            continue
        if current.is_empty():
            continue
        var t := line.strip_edges()
        if t.begins_with("offset_left = "): current["_ox"] = float(t.trim_prefix("offset_left = "))
        elif t.begins_with("offset_top = "): current["_oy"] = float(t.trim_prefix("offset_top = "))
        elif t.begins_with("offset_right = "): current["_sx"] = float(t.trim_prefix("offset_right = ")) - float(current["_ox"])
        elif t.begins_with("offset_bottom = "): current["_sy"] = float(t.trim_prefix("offset_bottom = ")) - float(current["_oy"])
        elif t.begins_with("anchor_right = 1.0"): current["anchors_full"] = true
        elif t.begins_with("custom_minimum_size = Vector2("):
            var inner := t.trim_prefix("custom_minimum_size = Vector2(").trim_suffix(")")
            var parts := inner.split(",")
            if parts.size() == 2:
                current["_sx"] = maxf(float(current["_sx"]), float(parts[0].strip_edges()))
                current["_sy"] = maxf(float(current["_sy"]), float(parts[1].strip_edges()))
    if not current.is_empty():
        controls.append(current)
    for c in controls:
        c["rect"] = Rect2(float(c["_ox"]), float(c["_oy"]), float(c["_sx"]), float(c["_sy"]))
        c.erase("_ox"); c.erase("_oy"); c.erase("_sx"); c.erase("_sy"); c.erase("_ax"); c.erase("_ay")
    return controls


func evaluate_project() -> Dictionary:
    var cfg := ConfigFile.new()
    var issues: Array = []
    var base := Vector2(1152, 648)
    var stretch_mode := "canvas_items"
    var aspect := "expand"
    if cfg.load("res://project.godot") == OK:
        base = Vector2(float(cfg.get_value("display", "window/size/viewport_width", 1152)),
            float(cfg.get_value("display", "window/size/viewport_height", 648)))
        stretch_mode = str(cfg.get_value("display", "window/stretch/mode", "canvas_items"))
        aspect = str(cfg.get_value("display", "window/stretch/aspect", "expand"))
    var scenes: Array = []
    _walk_scenes("res://", scenes)
    var checked := 0
    for path in scenes:
        var text := FileAccess.get_file_as_string(path)
        for control in _parse_controls(path, text):
            checked += 1
            for vp in viewports:
                issues.append_array(evaluate_control(control, base, vp, stretch_mode, aspect))
    return {"summary": {"controls": checked, "scenes": scenes.size(), "viewports": viewports.size(),
            "issues": issues.size(), "base_size": base, "stretch_mode": stretch_mode, "aspect": aspect},
        "issues": issues, "viewports": viewports}


func _walk_scenes(dir_path: String, out: Array) -> void:
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
            if name != ".godot" and name != "addons":
                _walk_scenes(full, out)
        elif name.get_extension() == "tscn":
            out.append(full)
        name = dir.get_next()
    dir.list_dir_end()


func to_json(result: Dictionary) -> String:
    return JSON.stringify({"summary": result["summary"], "issues": result["issues"]}, "\t")


func to_markdown(result: Dictionary) -> String:
    var s: Dictionary = result["summary"]
    var lines: Array[String] = ["# Responsive UI Report", "",
        "Checked %d controls in %d scenes against %d screen sizes (base %s, stretch %s/%s). %d problems." % [
            s["controls"], s["scenes"], s["viewports"], str(s["base_size"]), s["stretch_mode"], s["aspect"], s["issues"]], ""]
    for i in result["issues"]:
        lines.append("- [%s] %s" % [i["severity"], i["message"]])
    return "\n".join(lines) + "\n"
