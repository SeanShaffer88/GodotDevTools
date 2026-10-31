## Object Pool Advisor - spawn-site analysis operation.
## Reads GDScript and scene text (no editor APIs), finds every
## `.instantiate()` call, works out which scene it spawns, where it runs
## (per-frame callback, timer/fire handler, loop) and whether the spawned
## scene frees itself. Spawns that are frequent and short-lived are pool
## candidates. Optional recorded counts (from the runtime counter or your
## own logging) turn a static suspicion into measured evidence.
## Read-only: it suggests pools, it never rewrites code.
extends RefCounted

## Engine callbacks that run every frame or every input event.
const HOT_FUNCS: Array[String] = ["_process", "_physics_process", "_input", "_unhandled_input",
    "_unhandled_key_input", "_gui_input", "_shortcut_input", "_draw"]
## Function names that usually run repeatedly in gameplay (fire, spawn, timers).
const WARM_PATTERN := "(fire|shoot|spawn|emit|attack|burst|_on_.*timeout|_on_.*tick)"
const DEFAULT_OPTIONS := {"min_score": 4, "rate_threshold": 5.0}

var _preload_re := RegEx.create_from_string("^\\s*(?:@\\w+(?:\\([^)]*\\))?\\s+)*(?:const|var)\\s+(\\w+)[^=]*=\\s*(?:pre)?load\\(\\s*\"([^\"]+)\"\\s*\\)")
var _var_spawn_re := RegEx.create_from_string("(\\w+)\\.instantiate\\(")
var _direct_spawn_re := RegEx.create_from_string("(?:pre)?load\\(\\s*\"([^\"]+)\"\\s*\\)\\.instantiate\\(")
var _func_re := RegEx.create_from_string("^(?:static\\s+)?func\\s+(\\w+)")
var _self_free_re := RegEx.create_from_string("(?:^|[^\\w.])queue_free\\(\\)|\\bself\\.queue_free\\(\\)")
var _timer_connect_re := RegEx.create_from_string("\\.timeout\\.connect\\(\\s*(\\w+)")
var _warm_re := RegEx.create_from_string(WARM_PATTERN)


func run(scan_dir: String = "res://", counts: Dictionary = {}, options: Dictionary = DEFAULT_OPTIONS) -> Dictionary:
    if DirAccess.open(scan_dir) == null:
        return _empty_with(_issue("error", "scan_error", scan_dir, 0, "", "Cannot open scan directory.", "Provide an existing readable project directory."))
    var files: Array = []
    _walk(scan_dir, files)
    files.sort()
    var texts := {}
    for path in files:
        var file := FileAccess.open(path, FileAccess.READ)
        texts[path] = null if file == null else file.get_as_text()
    return analyze(texts, counts, options, true)


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
            elif name.get_extension().to_lower() in ["gd", "tscn"]:
                out.append(child)
        name = dir.get_next()
    dir.list_dir_end()


## texts maps res:// paths of .gd and .tscn files to their text (null =
## unreadable). counts is the recorded-session dictionary described in
## the README ({} when there is none).
func analyze(texts: Dictionary, counts: Dictionary = {}, options: Dictionary = DEFAULT_OPTIONS, load_missing: bool = false) -> Dictionary:
    var opts := DEFAULT_OPTIONS.duplicate()
    opts.merge(options, true)
    var issues: Array = []
    var rates := rates_from_counts(counts, issues)
    var self_free_cache := {}
    var sites: Array = []
    var paths: Array = texts.keys()
    paths.sort()
    for path in paths:
        if texts[path] == null:
            issues.append(_issue("error", "scan_error", str(path), 0, "", "Cannot read file.", "Check file permissions and retry."))
            continue
        if str(path).get_extension() != "gd":
            continue
        for site in parse_script(str(texts[path])):
            site["path"] = str(path)
            sites.append(site)
    var by_scene := {}
    for site in sites:
        var target: String = site["target"]
        var self_frees := false
        if target != "":
            self_frees = _scene_self_frees(target, texts, self_free_cache, load_missing)
        site["target_self_frees"] = self_frees
        var score := 0
        var reasons: Array = []
        if site["context"] == "hot":
            score += 3
            reasons.append("runs in %s every frame/event" % site["function"])
        elif site["context"] == "warm":
            score += 2
            reasons.append("runs in %s, which usually repeats" % site["function"])
        if site["in_loop"]:
            score += 1
            reasons.append("inside a loop")
        if self_frees:
            score += 2
            reasons.append("the spawned scene frees itself")
        if rates.has(target) and float(rates[target]["rate"]) >= float(opts["rate_threshold"]):
            score += 3
            reasons.append("recorded %.1f spawns/s" % rates[target]["rate"])
        site["score"] = score
        site["reasons"] = reasons
        if target == "":
            issues.append(_issue("info", "unresolved_spawn", site["path"], site["line"], site["function"],
                "Cannot tell which scene `%s` instantiates." % site["expr"],
                "Store the PackedScene in a preload() const/var so the target is known, or record counts at runtime."))
        elif score >= int(opts["min_score"]):
            issues.append(_issue("warning", "pool_candidate", site["path"], site["line"], site["function"],
                "%s spawns %s (score %d: %s)." % [site["function"], target, score, ", ".join(reasons)],
                "Pool it: pre-instantiate N copies, hide/disable instead of queue_free(), and reset state on reuse."))
        elif site["context"] == "hot":
            issues.append(_issue("warning", "hot_spawn", site["path"], site["line"], site["function"],
                "%s instantiates %s in a per-frame callback." % [site["function"], target],
                "Gate the spawn behind a cooldown or event, or pool the scene."))
        elif site["in_loop"]:
            issues.append(_issue("info", "burst_spawn", site["path"], site["line"], site["function"],
                "%s instantiates %s inside a loop." % [site["function"], target],
                "If this burst repeats, pre-warm a pool; one-off level setup is fine."))
        if target != "":
            if not by_scene.has(target):
                by_scene[target] = {"scene": target, "score": 0, "self_frees": self_frees, "sites": [], "rate": rates.get(target, {}).get("rate", null)}
            by_scene[target]["score"] = max(int(by_scene[target]["score"]), score)
            by_scene[target]["sites"].append({"path": site["path"], "line": site["line"], "function": site["function"], "context": site["context"], "in_loop": site["in_loop"]})
    for scene in rates.keys():
        var r: Dictionary = rates[scene]
        if float(r["rate"]) >= float(opts["rate_threshold"]):
            issues.append(_issue("warning", "high_spawn_rate", str(scene), 0, "",
                "Recorded %.1f spawns/s (%d spawned, %d freed in %.1fs)." % [r["rate"], r["spawned"], r["freed"], r["seconds"]],
                "Pool this scene; churn at this rate costs allocation and tree-entry time every frame."))
    var candidates: Array = by_scene.values()
    candidates.sort_custom(func(a, b): return int(a["score"]) > int(b["score"]) if int(a["score"]) != int(b["score"]) else str(a["scene"]) < str(b["scene"]))
    issues.sort_custom(func(a, b): return _sort_key(a) < _sort_key(b))
    var summary := {"scripts": 0, "spawn_sites": sites.size(), "candidates": 0, "issues": issues.size()}
    for path in paths:
        if str(path).get_extension() == "gd":
            summary["scripts"] += 1
    for issue in issues:
        if issue["kind"] == "pool_candidate":
            summary["candidates"] += 1
    return {"summary": summary, "options": opts, "scenes": candidates, "sites": sites, "issues": issues}


## One script's spawn sites: [{line, function, context, in_loop, target, expr}].
func parse_script(text: String) -> Array:
    var lines := text.split("\n")
    var preloads := {}
    var warm_names := {}
    for line in lines:
        var m := _preload_re.search(line)
        if m != null:
            preloads[m.get_string(1)] = m.get_string(2)
        for t in _timer_connect_re.search_all(line):
            warm_names[t.get_string(1)] = true
    var sites: Array = []
    var func_name := ""
    var loop_indents: Array = []
    for index in range(lines.size()):
        var raw: String = lines[index]
        var stripped := raw.strip_edges()
        if stripped == "" or stripped.begins_with("#"):
            continue
        var indent := _indent(raw)
        var fm := _func_re.search(raw)
        if fm != null:
            func_name = fm.get_string(1)
            loop_indents.clear()
            continue
        if indent == 0:
            func_name = ""
            loop_indents.clear()
            continue
        while not loop_indents.is_empty() and indent <= int(loop_indents.back()):
            loop_indents.pop_back()
        var code := stripped.get_slice("#", 0) if not stripped.contains("\"") else stripped
        var found: Array = []
        for dm in _direct_spawn_re.search_all(code):
            found.append({"target": dm.get_string(1), "expr": dm.get_string(0)})
        if found.is_empty():
            for vm in _var_spawn_re.search_all(code):
                var var_name := vm.get_string(1)
                found.append({"target": str(preloads.get(var_name, "")), "expr": var_name + ".instantiate()"})
        for f in found:
            if func_name == "":
                continue
            var context := "cold"
            if func_name in HOT_FUNCS:
                context = "hot"
            elif warm_names.has(func_name) or _warm_re.search(func_name) != null:
                context = "warm"
            sites.append({"line": index + 1, "function": func_name, "context": context,
                "in_loop": not loop_indents.is_empty(), "target": f["target"], "expr": f["expr"]})
        if (stripped.begins_with("for ") or stripped.begins_with("while ")) and stripped.ends_with(":"):
            loop_indents.append(indent)
    return sites


## True when the scene's root script calls queue_free() on itself.
func _scene_self_frees(scene_path: String, texts: Dictionary, cache: Dictionary, load_missing: bool) -> bool:
    if cache.has(scene_path):
        return cache[scene_path]
    cache[scene_path] = false
    var scene_text: Variant = _text(scene_path, texts, load_missing)
    if scene_text == null:
        return false
    var script_path := root_script(str(scene_text))
    if script_path == "":
        return false
    var script_text: Variant = _text(script_path, texts, load_missing)
    var result: bool = script_text != null and script_frees_self(str(script_text))
    cache[scene_path] = result
    return result


func script_frees_self(text: String) -> bool:
    for line in text.split("\n"):
        var code := line.strip_edges()
        if code.begins_with("#"):
            continue
        if _self_free_re.search(code) != null:
            return true
    return false


## The res:// path of the script attached to a scene's root node, or "".
func root_script(scene_text: String) -> String:
    var ext := {}
    var in_root := false
    for raw in scene_text.split("\n"):
        var line := raw.strip_edges()
        if line.begins_with("[ext_resource"):
            ext[_attr(line, "id")] = _attr(line, "path")
        elif line.begins_with("[node "):
            if in_root:
                return ""
            in_root = not line.contains(" parent=")
        elif line.begins_with("["):
            if in_root:
                return ""
        elif in_root and line.begins_with("script = ExtResource(\""):
            var id := line.trim_prefix("script = ExtResource(\"").get_slice("\"", 0)
            return str(ext.get(id, ""))
    return ""


## Validate a recorded-counts dictionary and turn it into per-scene rates.
## Format: {"seconds": float > 0, "scenes": {path: {"spawned": int, "freed": int}}}.
func rates_from_counts(counts: Dictionary, issues: Array) -> Dictionary:
    var rates := {}
    if counts.is_empty():
        return rates
    var seconds: Variant = counts.get("seconds")
    var scenes: Variant = counts.get("scenes")
    if typeof(seconds) not in [TYPE_INT, TYPE_FLOAT] or float(seconds) <= 0.0 or typeof(scenes) != TYPE_DICTIONARY:
        issues.append(_issue("error", "bad_counts", "counts", 0, "", "Counts need a positive \"seconds\" and a \"scenes\" object.", "Re-record with the runtime counter or fix the file by hand."))
        return rates
    for scene in scenes.keys():
        var entry: Variant = scenes[scene]
        if typeof(entry) != TYPE_DICTIONARY or typeof(entry.get("spawned")) not in [TYPE_INT, TYPE_FLOAT] or int(entry.get("spawned")) < 0:
            issues.append(_issue("error", "bad_counts", str(scene), 0, "", "Entry needs a non-negative \"spawned\" count.", "Fix or remove this entry."))
            continue
        var spawned := int(entry["spawned"])
        var freed := int(entry.get("freed", 0)) if typeof(entry.get("freed", 0)) in [TYPE_INT, TYPE_FLOAT] else 0
        rates[str(scene)] = {"spawned": spawned, "freed": freed, "seconds": float(seconds), "rate": spawned / float(seconds)}
    return rates


func _text(path: String, texts: Dictionary, load_missing: bool) -> Variant:
    if texts.has(path):
        return texts[path]
    if load_missing and FileAccess.file_exists(path):
        return FileAccess.get_file_as_string(path)
    return null


func _indent(line: String) -> int:
    var n := 0
    for c in line:
        if c == "\t":
            n += 4
        elif c == " ":
            n += 1
        else:
            break
    return n


func _attr(line: String, key: String) -> String:
    var marker := " " + key + "=\""
    var i := line.find(marker)
    if i < 0:
        return ""
    var start := i + marker.length()
    return line.substr(start, line.find("\"", start) - start)


func _sort_key(issue: Dictionary) -> String:
    return "%s|%06d|%s" % [issue["path"], int(issue["line"]), issue["kind"]]


func _issue(severity: String, kind: String, path: String, line: int, function: String, message: String, fix: String) -> Dictionary:
    return {"severity": severity, "kind": kind, "path": path, "line": line, "function": function, "message": message, "fix": fix}


func _empty_with(issue: Dictionary) -> Dictionary:
    return {"summary": {"scripts": 0, "spawn_sites": 0, "candidates": 0, "issues": 1}, "options": DEFAULT_OPTIONS.duplicate(), "scenes": [], "sites": [], "issues": [issue]}


func to_json(result: Dictionary) -> String:
    return JSON.stringify(result, "  ")


func to_markdown(result: Dictionary) -> String:
    var lines: Array[String] = ["# Object Pool Advisor", "",
        "Static spawn-site analysis; recorded counts, when supplied, add measured spawn rates.", "",
        "Summary: " + str(result["summary"]), "", "## Spawned scenes (highest score first)", "",
        "| Scene | Score | Self-frees | Spawns/s | Sites |", "|---|---|---|---|---|"]
    for scene in result.get("scenes", []):
        var rate: String = "-" if scene["rate"] == null else "%.1f" % scene["rate"]
        var where: Array = []
        for s in scene["sites"]:
            where.append("%s:%d" % [s["path"], s["line"]])
        lines.append("| `%s` | %d | %s | %s | %s |" % [scene["scene"], scene["score"], "yes" if scene["self_frees"] else "no", rate, ", ".join(where)])
    lines.append("")
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%d` %s: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["function"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
