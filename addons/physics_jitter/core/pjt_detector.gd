## Physics Jitter and Tunneling Detector - static risk checks.
## Tunneling: RigidBody2D/3D whose collision shape is small (circle/sphere
## radius, capsule radius, rectangle/box half-extent below min_size) and
## continuous_cd is off. Jitter: scripts extending a RigidBody that assign
## position/rotation/transform outside _integrate_forces (fighting the
## solver), CharacterBody scripts calling move_and_slide from _process
## instead of _physics_process, and a physics tick rate below 60 Hz.
extends RefCounted

const EXTS: Array[String] = ["tscn", "gd"]
## Parse Godot ConfigFile text (project.godot style) into {"section/key": value-text}.
## Multi-line values (dictionaries, arrays) are joined until brackets balance.
func parse_ini(text: String) -> Dictionary:
    var out := {}
    var section := ""
    var pending_key := ""
    var pending := ""
    var lines := text.split("\n")
    for index in range(lines.size()):
        var line: String = lines[index]
        if pending_key != "":
            pending += "\n" + line
            if _balanced(pending):
                out[pending_key] = {"value": pending.strip_edges(), "line": out[pending_key]["line"]}
                pending_key = ""
            continue
        var s := line.strip_edges()
        if s == "" or s.begins_with(";") or s.begins_with("#"):
            continue
        if s.begins_with("[") and s.ends_with("]"):
            section = s.substr(1, s.length() - 2)
            continue
        var eq := s.find("=")
        if eq < 0:
            continue
        var key := s.substr(0, eq).strip_edges()
        var full := key if section == "" else section + "/" + key
        var value := s.substr(eq + 1).strip_edges()
        out[full] = {"value": value, "line": index + 1}
        if not _balanced(value):
            pending_key = full
            pending = value
    return out


func _balanced(v: String) -> bool:
    var depth := 0
    var in_str := false
    var prev := ""
    for c in v:
        if c == "\"" and prev != "\\":
            in_str = not in_str
        elif not in_str:
            if c in ["{", "["]:
                depth += 1
            elif c in ["}", "]"]:
                depth -= 1
        prev = c
    return depth <= 0

const DEFAULTS := {"project": "res://project.godot", "min_size": 4.0}

var _func_re := RegEx.create_from_string("^func\\s+([A-Za-z_][A-Za-z0-9_]*)")
var _assign_re := RegEx.create_from_string("^\\s*(?:self\\.)?(position|global_position|rotation|global_rotation|transform|global_transform)\\s*([+\\-*/]?=)")


func run(input: String = "res://", options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    if DirAccess.open(input) == null:
        return _fail(input, "Cannot open scan directory.", "Provide an existing readable project directory.")
    var paths: Array = []
    _walk(input, paths)
    paths.sort()
    var texts := {}
    for p in paths:
        texts[p] = FileAccess.get_file_as_string(p)
    opts["project_text"] = FileAccess.get_file_as_string(str(opts["project"])) if FileAccess.file_exists(str(opts["project"])) else ""
    return analyze(texts, opts)


func analyze(texts: Dictionary, options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    var issues: Array = []
    var ini := parse_ini(str(opts.get("project_text", "")))
    var ticks := int(str(ini.get("physics/common/physics_ticks_per_second", {"value": "60"})["value"]))
    if ticks < 60:
        issues.append(_issue("warning", "low_tick_rate", str(opts["project"]), int(ini.get("physics/common/physics_ticks_per_second", {"line": 0})["line"]), "Physics runs at %d Hz; fast objects move further per step and motion can stutter against the display rate." % ticks, "Use at least 60 Hz (match or divide the display rate), or enable physics interpolation where available."))
    for path in texts.keys():
        if texts[path] == null:
            issues.append(_issue("error", "scan_error", str(path), 0, "Cannot read file.", "Check file permissions and retry."))
            continue
        var text := str(texts[path])
        if str(path).get_extension() == "tscn":
            _scene(str(path), text, float(opts["min_size"]), issues)
        else:
            _script(str(path), text, issues)
    return _finish({"physics_ticks": ticks}, issues)


func _scene(path: String, text: String, min_size: float, issues: Array) -> void:
    var subs := {}
    var cur := {}
    var nodes: Array = []
    var lines := text.split("\n")
    for index in range(lines.size()):
        var s := lines[index].strip_edges()
        if s.begins_with("[sub_resource"):
            cur = {"type": s.get_slice("type=\"", 1).get_slice("\"", 0), "props": {}}
            subs[s.get_slice("id=\"", 1).get_slice("\"", 0)] = cur
        elif s.begins_with("[node "):
            var parent := s.get_slice("parent=\"", 1).get_slice("\"", 0) if s.contains("parent=\"") else ""
            var name := s.get_slice("name=\"", 1).get_slice("\"", 0)
            cur = {"type": s.get_slice("type=\"", 1).get_slice("\"", 0) if s.contains("type=\"") else "", "name": name, "path": "." if parent == "" else (name if parent == "." else parent + "/" + name), "parent": parent, "props": {}, "line": index + 1}
            nodes.append(cur)
        elif s.begins_with("["):
            cur = {}
        elif not cur.is_empty() and s.contains(" = "):
            cur["props"][s.get_slice(" = ", 0)] = s.substr(s.get_slice(" = ", 0).length() + 3)
    for body in nodes:
        if body["type"] not in ["RigidBody2D", "RigidBody3D"]:
            continue
        var ccd := str(body["props"].get("continuous_cd", "0"))
        if ccd not in ["0", "false"]:
            continue
        for shape_node in nodes:
            if shape_node["parent"] != body["path"] or not str(shape_node["type"]).begins_with("CollisionShape"):
                continue
            var ref := str(shape_node["props"].get("shape", "")).get_slice("\"", 1)
            if not subs.has(ref):
                continue
            var size := _shape_size(subs[ref])
            if size >= 0.0 and size < min_size:
                issues.append(_issue("warning", "tunneling_risk", path, body["line"], "%s (%s) has a %s of size %.2f and continuous collision detection off." % [body["name"], body["type"], subs[ref]["type"], size], "Enable continuous_cd on fast small bodies, enlarge the shape, or use a ShapeCast/RayCast sweep for bullets."))


func _shape_size(sub: Dictionary) -> float:
    var p: Dictionary = sub["props"]
    match sub["type"]:
        "CircleShape2D", "SphereShape3D":
            return float(p.get("radius", "10.0" if sub["type"] == "CircleShape2D" else "0.5"))
        "CapsuleShape2D", "CapsuleShape3D", "CylinderShape3D":
            return float(p.get("radius", "10.0" if sub["type"] == "CapsuleShape2D" else "0.5"))
        "RectangleShape2D":
            var v := str(p.get("size", "Vector2(20, 20)")).get_slice("(", 1).get_slice(")", 0).split(",")
            return min(float(v[0]), float(v[1])) / 2.0
        "BoxShape3D":
            var v3 := str(p.get("size", "Vector3(1, 1, 1)")).get_slice("(", 1).get_slice(")", 0).split(",")
            return min(float(v3[0]), min(float(v3[1]), float(v3[2]))) / 2.0
    return -1.0


func _script(path: String, text: String, issues: Array) -> void:
    var head := text.substr(0, 400)
    var rigid := head.contains("extends RigidBody2D") or head.contains("extends RigidBody3D")
    var character := head.contains("extends CharacterBody2D") or head.contains("extends CharacterBody3D")
    if not rigid and not character:
        return
    var fn := ""
    var lines := text.split("\n")
    for index in range(lines.size()):
        var m := _func_re.search(lines[index])
        if m != null:
            fn = m.get_string(1)
            continue
        var code := lines[index].get_slice("#", 0)
        if rigid and fn != "_integrate_forces" and _assign_re.search(code) != null:
            issues.append(_issue("warning", "transform_fight", path, index + 1, "A RigidBody script sets its transform directly in %s; the physics solver overwrites it, causing jitter." % fn, "Move it with forces/impulses or linear_velocity, or set the state inside _integrate_forces; use a CharacterBody or AnimatableBody if it should be moved by code."))
        if character and fn == "_process" and code.contains("move_and_slide("):
            issues.append(_issue("warning", "physics_in_process", path, index + 1, "move_and_slide() is called from _process; movement then runs at the render rate, not the physics rate.", "Call it from _physics_process."))


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
    var lines: Array = ["# Physics Jitter and Tunneling Detector", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
