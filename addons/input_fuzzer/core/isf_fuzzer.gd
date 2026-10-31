## Input Sequence Fuzzer - seeded input generation.
## Reads action names (and whether they have events) from the [input]
## section of a project file, then builds sequences of steps
## {frame, action, hold} with a seeded RandomNumberGenerator: same seed,
## same sequences. runtime/isf_player.gd replays a sequence by pressing and
## releasing InputEventActions on the scheduled frames. Pair with the Time
## Machine or your own assertions to catch crashes and stuck states.
extends RefCounted

const EXTS: Array[String] = ["godot"]
const DEFAULTS := {"seed": 1, "sequences": 5, "length": 60, "max_hold": 30, "max_gap": 10, "include_ui": false}


func run(input: String = "res://project.godot", options: Dictionary = {}) -> Dictionary:
    if not FileAccess.file_exists(input):
        return _fail(input, "Project file not found.", "Pass --project=<path to project.godot>.", "bad_input")
    return evaluate(actions(FileAccess.get_file_as_string(input)), options, input)


## {action: has_events} from a project file's [input] section.
func actions(text: String) -> Dictionary:
    var out := {}
    var in_input := false
    var current := ""
    for raw in text.split("\n"):
        var s := raw.strip_edges()
        if s.begins_with("[") and s.ends_with("]") and not s.begins_with("[{") and s.find("=") < 0:
            in_input = s == "[input]"
            current = ""
            continue
        if not in_input:
            continue
        var m := RegEx.create_from_string("^([A-Za-z0-9_./-]+)=\\{").search(s)
        if m != null:
            current = m.get_string(1)
            out[current] = false
        if current != "" and s.contains("Object(InputEvent"):
            out[current] = true
    return out


func evaluate(acts: Dictionary, options: Dictionary = {}, path: String = "") -> Dictionary:
    var opts := _opts(options)
    var issues: Array = []
    var usable: Array = []
    var names: Array = acts.keys()
    names.sort()
    for a in names:
        if str(a).begins_with("ui_") and not opts["include_ui"]:
            continue
        if not acts[a]:
            issues.append(_issue("warning", "unbound_action", path, 0, "Action %s has no input events; players cannot trigger it." % a, "Bind it in Project Settings > Input Map, or remove it."))
            continue
        usable.append(a)
    if usable.is_empty():
        issues.append(_issue("error", "no_actions", path, 0, "No bound actions to fuzz.", "Bind input events, or pass --include-ui."))
        return _finish({"actions": 0, "sequences": 0}, issues, {"sequences": []})
    var rng := RandomNumberGenerator.new()
    rng.seed = int(opts["seed"])
    var seqs: Array = []
    for s in range(int(opts["sequences"])):
        var steps: Array = []
        var frame := 0
        for i in range(int(opts["length"])):
            frame += rng.randi_range(0, int(opts["max_gap"]))
            steps.append({"frame": frame, "action": usable[rng.randi_range(0, usable.size() - 1)], "hold": rng.randi_range(1, int(opts["max_hold"]))})
        seqs.append({"seed": int(opts["seed"]), "index": s, "steps": steps})
    return _finish({"actions": usable.size(), "sequences": seqs.size()}, issues, {"actions": usable, "sequences": seqs})


## Events due on one frame of a sequence: [[action, pressed]] (releases first).
func events_for_frame(seq: Dictionary, frame: int) -> Array:
    var releases: Array = []
    var presses: Array = []
    for st in seq.get("steps", []):
        if int(st["frame"]) == frame:
            presses.append([st["action"], true])
        if int(st["frame"]) + int(st["hold"]) == frame:
            releases.append([st["action"], false])
    return releases + presses


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
    var lines: Array = ["# Input Sequence Fuzzer", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
