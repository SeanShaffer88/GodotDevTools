## Privacy and Permissions Auditor - data-flow inventory.
## Lists, with file and line: http(s)/ws(s) URLs; network classes
## (HTTPRequest, HTTPClient, WebSocketPeer, StreamPeerTCP, PacketPeerUDP,
## ENet/WebRTC peers, JavaScriptBridge); device identifiers
## (OS.get_unique_id, model/name/environment queries); clipboard reads and
## writes; microphone input (AudioStreamMicrophone, AudioEffectCapture,
## audio/driver/enable_input) and camera (CameraServer, CameraFeed); and
## OS.shell_open. Each entry is for a human to justify in the privacy policy
## and store listings. Not a legal assessment.
extends RefCounted

const EXTS: Array[String] = ["gd", "tscn", "tres", "godot", "cfg", "cs"]
const DEFAULTS := {}
const PATTERNS := [
    ["network_endpoint", "\"((?:https?|wss?)://[^\"\\s]+)\"", "info", "Document what is sent to this endpoint and why."],
    ["network_api", "\\b(HTTPRequest|HTTPClient|WebSocketPeer|WebSocketMultiplayerPeer|StreamPeerTCP|StreamPeerTLS|PacketPeerUDP|ENetMultiplayerPeer|ENetConnection|WebRTCPeerConnection|WebRTCMultiplayerPeer|JavaScriptBridge)\\b", "info", "Confirm what this connection sends and whether players are told."],
    ["device_identifier", "OS\\.(get_unique_id|get_model_name|get_processor_name|get_environment)\\(|DisplayServer\\.(screen_get_size|get_name)\\(", "warning", "Identifiers can be personal data; avoid sending them, or disclose and justify it."],
    ["clipboard", "DisplayServer\\.clipboard_(get|set|get_primary|set_primary)\\(", "info", "Read the clipboard only on a player action."],
    ["microphone", "AudioStreamMicrophone|AudioEffectCapture|AudioEffectRecord|audio/driver/enable_input=true", "warning", "Microphone use needs a permission prompt and disclosure on most platforms."],
    ["camera", "\\bCameraServer\\b|\\bCameraFeed\\b", "warning", "Camera use needs a permission prompt and disclosure."],
    ["external_open", "OS\\.shell_open\\(", "info", "Opening links or files leaves the game; make the destination clear to players."]]


func analyze(texts: Dictionary, options: Dictionary = {}) -> Dictionary:
    var issues: Array = []
    var seen := {}
    var counts := {}
    var paths: Array = texts.keys()
    paths.sort()
    # Compile each pattern once; compiling per line dominated large scans.
    var compiled: Array = PATTERNS.map(func(p): return RegEx.create_from_string(p[1]))
    for path in paths:
        if texts[path] == null:
            issues.append(_issue("error", "scan_error", str(path), 0, "Cannot read file.", "Check file permissions and retry."))
            continue
        var lines := str(texts[path]).split("\n")
        for index in range(lines.size()):
            var line: String = lines[index]
            if line.strip_edges().begins_with("#"):
                continue
            for pi in PATTERNS.size():
                var p: Array = PATTERNS[pi]
                var re: RegEx = compiled[pi]
                for m: RegExMatch in re.search_all(line):
                    var what := m.get_string(1) if m.get_group_count() >= 1 and m.get_string(1) != "" else m.get_string()
                    var key := "%s|%s|%s" % [p[0], path, what] if p[0] != "network_endpoint" else "%s|%s" % [p[0], what]
                    if seen.has(key):
                        continue
                    seen[key] = true
                    counts[p[0]] = int(counts.get(p[0], 0)) + 1
                    issues.append(_issue(p[2], p[0], str(path), index + 1, "%s: %s" % [p[0].replace("_", " "), what], p[3]))
    return _finish(counts, issues)

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
    var lines: Array = ["# Privacy and Permissions Auditor", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
