## Particle Budget Inspector - static emitter budget operation.
## Reads scene text (no renderer, no editor APIs), finds every
## GPUParticles2D/3D and CPUParticles2D/3D node, follows instanced
## child scenes, and totals the particle capacity each scene could hold
## at once. Numbers are capacities from scene properties (amount x
## amount_ratio), not live counts: a script can still change amount or
## emitting at runtime. Read-only.
extends RefCounted

const EMITTER_TYPES: Array[String] = ["GPUParticles2D", "GPUParticles3D", "CPUParticles2D", "CPUParticles3D"]
## Defaults used when a property is omitted from scene text (Godot 4 defaults).
const DEFAULT_AMOUNT := 8
const DEFAULT_LIFETIME := 1.0
const DEFAULT_BUDGET := {"max_scene": 4000, "max_emitter": 1000, "max_cpu_emitter": 500, "max_preprocess": 1.0}
const MAX_DEPTH := 16


func find_scenes(scan_dir: String) -> Array:
    var out: Array = []
    _walk(scan_dir, out)
    out.sort()
    return out


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
            elif name.get_extension().to_lower() == "tscn":
                out.append(child)
        name = dir.get_next()
    dir.list_dir_end()


func run(scan_dir: String = "res://", budget: Dictionary = DEFAULT_BUDGET) -> Dictionary:
    if DirAccess.open(scan_dir) == null:
        return {"summary": {"scenes": 0, "emitters": 0, "issues": 1, "peak_worst_case": 0},
            "scenes": [], "issues": [_issue("error", "scan_error", scan_dir, "", "Cannot open scan directory.", "Provide an existing readable project directory.")]}
    var texts := {}
    for path in find_scenes(scan_dir):
        texts[path] = _read(path)
    return analyze(texts, budget, true)


func _read(path: String) -> Variant:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return null
    return file.get_as_text()


## Input is a scene-path-to-text dictionary (null = unreadable). When
## load_missing is true, instanced scenes not in the dictionary are read
## from disk; otherwise they are reported as missing_scene.
func analyze(texts: Dictionary, budget: Dictionary = DEFAULT_BUDGET, load_missing: bool = false) -> Dictionary:
    var limits := DEFAULT_BUDGET.duplicate()
    limits.merge(budget, true)
    var cache := {}
    var issues: Array = []
    var scenes: Array = []
    var emitter_total := 0
    var peak := 0
    var paths: Array = texts.keys()
    paths.sort()
    for path in paths:
        if texts[path] == null:
            issues.append(_issue("error", "scan_error", str(path), "", "Cannot read scene.", "Check file permissions and retry."))
            continue
        var parsed: Dictionary = _parse_cached(str(path), texts, cache, load_missing)
        var own: Array = parsed["emitters"]
        emitter_total += own.size()
        for em in own:
            _check_emitter(str(path), em, limits, issues)
        var flat: Array = []
        _flatten(str(path), "", texts, cache, load_missing, [], flat, issues, 0)
        if flat.is_empty():
            continue
        var always_on := 0
        var worst := 0
        for em in flat:
            worst += int(em["capacity"])
            if em["emitting"] and not em["one_shot"]:
                always_on += int(em["capacity"])
        peak = max(peak, worst)
        scenes.append({"path": str(path), "emitters": flat, "always_on": always_on, "worst_case": worst})
        if worst > int(limits["max_scene"]):
            issues.append(_issue("warning", "scene_budget", str(path), "",
                "Scene can hold %d particles at once (budget %d) if every emitter is active." % [worst, int(limits["max_scene"])],
                "Lower amount on the largest emitters, use amount_ratio for quality tiers, or avoid running these effects together."))
    issues.sort_custom(func(a, b): return _sort_key(a) < _sort_key(b))
    return {"summary": {"scenes": scenes.size(), "emitters": emitter_total, "issues": issues.size(), "peak_worst_case": peak},
        "budget": limits, "scenes": scenes, "issues": issues}


func _check_emitter(path: String, em: Dictionary, limits: Dictionary, issues: Array) -> void:
    var node: String = em["node"]
    if int(em["capacity"]) > int(limits["max_emitter"]):
        issues.append(_issue("warning", "emitter_budget", path, node,
            "%s holds up to %d particles (budget %d)." % [em["type"], em["capacity"], int(limits["max_emitter"])],
            "Reduce amount, shorten lifetime with a higher emission rate only if the look allows, or split the effect by LOD."))
    if str(em["type"]).begins_with("CPU") and int(em["capacity"]) > int(limits["max_cpu_emitter"]):
        issues.append(_issue("warning", "cpu_heavy", path, node,
            "CPU emitter simulates %d particles on the main thread (CPU budget %d)." % [em["capacity"], int(limits["max_cpu_emitter"])],
            "Convert to the GPU variant (editor: Particles > Convert to GPUParticles) where the target renderer supports it."))
    if float(em["preprocess"]) > float(limits["max_preprocess"]):
        issues.append(_issue("warning", "preprocess_cost", path, node,
            "preprocess = %.2fs simulates that much time in one frame when the emitter enters the tree." % em["preprocess"],
            "Lower preprocess, or spawn the effect before it becomes visible."))


## Recursively collect emitters of a scene plus its instanced children,
## with each emitter's path prefixed by the instance chain.
func _flatten(path: String, prefix: String, texts: Dictionary, cache: Dictionary, load_missing: bool, stack: Array, out: Array, issues: Array, depth: int) -> void:
    if path in stack or depth > MAX_DEPTH:
        issues.append(_issue("error", "instance_cycle", stack[0] if not stack.is_empty() else path, prefix,
            "Instance chain loops back to %s." % path, "Break the cycle; a scene cannot contain itself."))
        return
    var parsed: Dictionary = _parse_cached(path, texts, cache, load_missing)
    if parsed.is_empty():
        return
    for em in parsed["emitters"]:
        var copy: Dictionary = em.duplicate()
        copy["node"] = prefix.path_join(em["node"]) if prefix != "" else em["node"]
        copy["source"] = path
        out.append(copy)
    var next_stack := stack.duplicate()
    next_stack.append(path)
    for inst in parsed["instances"]:
        var child: String = inst["scene"]
        var where: String = prefix.path_join(inst["node"]) if prefix != "" else inst["node"]
        if child == "":
            issues.append(_issue("warning", "missing_scene", path, where, "Instance refers to an unknown ext_resource.", "Fix the ext_resource id in the scene file."))
            continue
        if not texts.has(child) and not (load_missing and FileAccess.file_exists(child)):
            issues.append(_issue("warning", "missing_scene", path, where, "Instanced scene %s was not found; its emitters are not counted." % child, "Restore the scene or update the instance path."))
            continue
        _flatten(child, where, texts, cache, load_missing, next_stack, out, issues, depth + 1)


func _parse_cached(path: String, texts: Dictionary, cache: Dictionary, load_missing: bool) -> Dictionary:
    if cache.has(path):
        return cache[path]
    var text: Variant = texts.get(path)
    if text == null and load_missing and not texts.has(path):
        text = _read(path)
    var parsed: Dictionary = {} if text == null else parse_scene(str(text))
    cache[path] = parsed
    return parsed


## Parse scene text into {emitters:[...], instances:[{node, scene}]}.
## Node paths are relative to the scene root ("." for the root).
func parse_scene(text: String) -> Dictionary:
    var ext := {}
    var emitters: Array = []
    var instances: Array = []
    var current: Dictionary = {}
    for raw in text.split("\n"):
        var line := raw.strip_edges()
        if line.begins_with("[ext_resource"):
            ext[_attr(line, "id")] = _attr(line, "path")
            current = {}
        elif line.begins_with("[node "):
            _close(current, emitters)
            var name := _attr(line, "name")
            var parent := _attr(line, "parent")
            var node_path := "." if not line.contains("parent=") else (name if parent == "." else parent.path_join(name))
            current = {"node": node_path, "type": _attr(line, "type"), "amount": DEFAULT_AMOUNT,
                "amount_ratio": 1.0, "lifetime": DEFAULT_LIFETIME, "emitting": true, "one_shot": false,
                "preprocess": 0.0, "explosiveness": 0.0}
            var inst_id := _instance_id(line)
            if inst_id != "":
                instances.append({"node": node_path, "scene": str(ext.get(inst_id, ""))})
        elif line.begins_with("["):
            _close(current, emitters)
            current = {}
        elif not current.is_empty() and line.contains(" = "):
            var key := line.get_slice(" = ", 0)
            var value := line.substr(key.length() + 3)
            match key:
                "amount": current["amount"] = int(value)
                "amount_ratio": current["amount_ratio"] = float(value)
                "lifetime": current["lifetime"] = float(value)
                "emitting": current["emitting"] = value == "true"
                "one_shot": current["one_shot"] = value == "true"
                "preprocess": current["preprocess"] = float(value)
                "explosiveness": current["explosiveness"] = float(value)
    _close(current, emitters)
    return {"emitters": emitters, "instances": instances}


func _close(current: Dictionary, emitters: Array) -> void:
    if current.is_empty() or str(current["type"]) not in EMITTER_TYPES:
        return
    var ratio: float = clampf(float(current["amount_ratio"]), 0.0, 1.0)
    # amount_ratio exists on GPU emitters only (Godot 4.2+).
    if str(current["type"]).begins_with("CPU"):
        ratio = 1.0
    current["capacity"] = int(ceil(float(current["amount"]) * ratio))
    emitters.append(current.duplicate())


func _instance_id(line: String) -> String:
    var marker := "instance=ExtResource(\""
    var i := line.find(marker)
    if i < 0:
        return ""
    var start := i + marker.length()
    return line.substr(start, line.find("\"", start) - start)


func _attr(line: String, key: String) -> String:
    var marker := " " + key + "=\""
    var i := line.find(marker)
    if i < 0:
        return ""
    var start := i + marker.length()
    return line.substr(start, line.find("\"", start) - start)


func _sort_key(issue: Dictionary) -> String:
    return "%s|%s|%s" % [issue["path"], issue["node"], issue["kind"]]


func _issue(severity: String, kind: String, path: String, node: String, message: String, fix: String) -> Dictionary:
    return {"severity": severity, "kind": kind, "path": path, "node": node, "message": message, "fix": fix}


func to_json(result: Dictionary) -> String:
    return JSON.stringify(result, "  ")


func to_markdown(result: Dictionary) -> String:
    var lines: Array[String] = ["# Particle Budget Inspector", "",
        "Capacities come from scene properties (amount x amount_ratio); scripts may change them at runtime.", "",
        "Summary: " + str(result["summary"]), "", "## Scenes", "",
        "| Scene | Emitters | Always on | Worst case |", "|---|---|---|---|"]
    for scene in result.get("scenes", []):
        lines.append("| `%s` | %d | %d | %d |" % [scene["path"], scene["emitters"].size(), scene["always_on"], scene["worst_case"]])
    lines.append("")
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s` %s: %s %s" % [issue["kind"], issue["path"], issue["node"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
