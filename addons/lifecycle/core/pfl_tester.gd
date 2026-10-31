## Pause, Focus, and Lifecycle Tester - pause and suspend behaviour.
## Resolves each scene node's effective process mode by Godot's inheritance
## rules (INHERIT follows the parent; the scene root inherits PAUSABLE) to
## decide which scripted nodes (with _process, _physics_process or input
## callbacks) run while the tree is paused. A node whose script toggles
## get_tree().paused, or whose name mentions pause, must run while paused or
## the game can never resume. Gameplay nodes running while paused are noted.
## Projects that pause but never handle focus loss or app suspension, and
## scripts timing gameplay with the wall clock (which keeps counting while
## paused), are reported.
extends RefCounted

const EXTS: Array[String] = ["tscn", "gd"]
const DEFAULTS := {}
const CALLBACKS: Array[String] = ["_process", "_physics_process", "_input", "_unhandled_input", "_unhandled_key_input", "_gui_input", "_shortcut_input"]
const RUNS_WHEN_PAUSED := [2, 3]


func analyze(texts: Dictionary, options: Dictionary = {}) -> Dictionary:
    var issues: Array = []
    var scripts := {}
    var pauses := false
    var focus := false
    for path in texts.keys():
        if texts[path] == null or str(path).get_extension() != "gd":
            continue
        var t := str(texts[path])
        var info := {"callbacks": CALLBACKS.filter(func(c): return t.contains("func " + c + "(")), "toggles_pause": t.contains("paused =")}
        scripts[path] = info
        pauses = pauses or info["toggles_pause"]
        focus = focus or t.contains("NOTIFICATION_APPLICATION_FOCUS_OUT") or t.contains("NOTIFICATION_WM_WINDOW_FOCUS_OUT") or t.contains("NOTIFICATION_APPLICATION_PAUSED") or t.contains("focus_exited")
        var lines := t.split("\n")
        for index in range(lines.size()):
            if lines[index].contains("Time.get_ticks_msec()") or lines[index].contains("Time.get_unix_time_from_system()") or lines[index].contains("Time.get_ticks_usec()"):
                issues.append(_issue("info", "wallclock_timing", str(path), index + 1, "Wall-clock time keeps counting while the game is paused or suspended.", "Accumulate delta in _process (or use a Timer) for gameplay timers so pausing stops them."))
                break
    for path in texts.keys():
        if texts[path] == null or str(path).get_extension() != "tscn":
            continue
        var ext := {}
        var nodes := {}
        var order: Array = []
        var cur: Dictionary = {}
        var lines := str(texts[path]).split("\n")
        for index in range(lines.size()):
            var s := lines[index].strip_edges()
            if s.begins_with("[ext_resource"):
                ext[s.get_slice(" id=\"", 1).get_slice("\"", 0)] = s.get_slice(" path=\"", 1).get_slice("\"", 0)
            if s.begins_with("[node "):
                var name := s.get_slice("name=\"", 1).get_slice("\"", 0)
                var parent := s.get_slice("parent=\"", 1).get_slice("\"", 0) if s.contains("parent=\"") else ""
                var npath := "." if parent == "" else (name if parent == "." else parent + "/" + name)
                cur = {"name": name, "parent": parent, "mode": 0, "script": "", "line": index + 1}
                nodes[npath] = cur
                order.append(npath)
            elif s.begins_with("["):
                cur = {}
            elif not cur.is_empty() and s.begins_with("process_mode = "):
                cur["mode"] = int(s.get_slice(" = ", 1))
            elif not cur.is_empty() and s.begins_with("script = ExtResource(\""):
                cur["script"] = str(ext.get(s.get_slice("\"", 1), ""))
        for npath in order:
            var n: Dictionary = nodes[npath]
            var eff := effective_mode(nodes, npath)
            var sinfo: Dictionary = scripts.get(n["script"], {"callbacks": [], "toggles_pause": false})
            if sinfo["callbacks"].is_empty():
                continue
            var runs: bool = eff in RUNS_WHEN_PAUSED
            var is_pause_ui: bool = sinfo["toggles_pause"] or str(n["name"]).to_lower().contains("pause")
            if is_pause_ui and not runs:
                issues.append(_issue("error", "pause_menu_frozen", str(path), n["line"], "%s handles pausing but stops processing when the tree is paused, so it can never unpause." % n["name"], "Set its process_mode to When Paused (or Always)."))
            elif not is_pause_ui and runs:
                issues.append(_issue("info", "keeps_running_when_paused", str(path), n["line"], "%s runs %s while the game is paused (process_mode %s)." % [n["name"], ", ".join(sinfo["callbacks"]), ["Inherit", "Pausable", "When Paused", "Always", "Disabled"][eff]], "Confirm it should; gameplay usually should stop."))
    if pauses and not focus:
        issues.append(_issue("info", "no_focus_pause", "res://", 0, "The game can pause, but no script handles window focus loss or app suspension.", "Pause on NOTIFICATION_APPLICATION_FOCUS_OUT / NOTIFICATION_APPLICATION_PAUSED (mobile) so players do not die while away."))
    return _finish({"scripts": scripts.size(), "pause_toggle_found": pauses, "focus_handling_found": focus}, issues)


## Effective process mode (1 PAUSABLE, 2 WHEN_PAUSED, 3 ALWAYS, 4 DISABLED) after INHERIT resolution.
func effective_mode(nodes: Dictionary, npath: String) -> int:
    var p := npath
    while nodes.has(p):
        var m := int(nodes[p]["mode"])
        if m != 0:
            return m
        var parent: String = nodes[p]["parent"]
        if parent == "":
            return 1
        p = parent
    return 1

func run(input: String = "res://", options: Dictionary = {}) -> Dictionary:
    if DirAccess.open(input) == null:
        return _fail(input, "Cannot open scan directory.", "Provide an existing readable project directory.")
    var paths: Array = []
    _walk(input, paths)
    paths.sort()
    var texts := {}
    for path in paths:
        var file := FileAccess.open(path, FileAccess.READ)
        texts[path] = null if file == null else file.get_as_text()
    return analyze(texts, options)


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
    var lines: Array = ["# Pause, Focus, and Lifecycle Tester", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
