## Offline and Poor-Connection Test Harness - fail the network on purpose.
## Static half: HTTPRequest nodes in scenes without a timeout (the default 0
## waits forever), scripts creating HTTPRequest without setting timeout, and
## request_completed handlers that never look at the result or response
## code. Runtime half: runtime/ocn_http.gd is a drop-in node with
## HTTPRequest's request() and request_completed signal that applies a
## seeded fault profile (offline, timeout, slow, http_error) per URL before
## falling back to a real HTTPRequest. decide() is deterministic per seed and
## request number, so a failing run can be replayed.
extends RefCounted

const EXTS: Array[String] = ["gd", "tscn"]
const DEFAULTS := {"profile": ""}
const FAULTS: Array[String] = ["offline", "timeout", "slow", "http_error", "none"]


func run(input: String = "res://", options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    var profile := {}
    if str(opts["profile"]) != "":
        var p: Variant = _read_json(str(opts["profile"]))
        if typeof(p) != TYPE_DICTIONARY or typeof(p.get("rules")) != TYPE_ARRAY:
            return _fail(str(opts["profile"]), "Profile missing or without a rules array.", "See the README for the profile format.", "bad_profile")
        profile = p
    if DirAccess.open(input) == null:
        return _fail(input, "Cannot open scan directory.", "Provide an existing readable project directory.")
    var paths: Array = []
    _walk(input, paths)
    paths.sort()
    var texts := {}
    for f in paths:
        texts[f] = FileAccess.get_file_as_string(f)
    return analyze(texts, {"profile_data": profile})


## Fault for request number `index` to `url` under a profile: {fault, delay_ms, status}.
func decide(profile: Dictionary, url: String, index: int) -> Dictionary:
    var rng := RandomNumberGenerator.new()
    rng.seed = hash("%s|%d|%s" % [profile.get("seed", 0), index, url])
    for r in profile.get("rules", []):
        var pattern := str(r.get("match", "*"))
        if pattern != "*" and not url.contains(pattern):
            continue
        if rng.randf() < float(r.get("rate", 1.0)):
            return {"fault": str(r.get("fault", "none")), "delay_ms": int(r.get("delay_ms", 0)), "status": int(r.get("status", 500))}
    return {"fault": "none", "delay_ms": 0, "status": 0}


func analyze(texts: Dictionary, options: Dictionary = {}) -> Dictionary:
    var issues: Array = []
    var urls := {}
    for path in texts.keys():
        if texts[path] == null:
            issues.append(_issue("error", "scan_error", str(path), 0, "Cannot read file.", "Check file permissions and retry."))
            continue
        var t := str(texts[path])
        var lines := t.split("\n")
        if str(path).get_extension() == "tscn":
            var in_http := false
            var has_timeout := false
            var start := 0
            for index in range(lines.size() + 1):
                var s := lines[index].strip_edges() if index < lines.size() else "["
                if s.begins_with("["):
                    if in_http and not has_timeout:
                        issues.append(_issue("warning", "no_timeout", str(path), start, "HTTPRequest node without a timeout waits forever on a dead connection.", "Set timeout (for example 10 seconds) and handle RESULT_TIMEOUT."))
                    in_http = s.begins_with("[node ") and s.contains("type=\"HTTPRequest\"")
                    has_timeout = false
                    start = index + 1
                elif in_http and s.begins_with("timeout = ") and float(s.get_slice(" = ", 1)) > 0.0:
                    has_timeout = true
            continue
        for m in RegEx.create_from_string("\"(https?://[^\"]+)\"").search_all(t):
            urls[m.get_string(1)] = true
        if t.contains("HTTPRequest.new()") and not RegEx.create_from_string("\\.timeout\\s*=\\s*[0-9]").search(t):
            var ln := 0
            for index in range(lines.size()):
                if lines[index].contains("HTTPRequest.new()"):
                    ln = index + 1
                    break
            issues.append(_issue("warning", "no_timeout", str(path), ln, "HTTPRequest created in code without setting timeout.", "Set .timeout before request() and handle RESULT_TIMEOUT."))
        for index in range(lines.size()):
            var fm := RegEx.create_from_string("^func\\s+([A-Za-z_][A-Za-z0-9_]*)\\s*\\(\\s*(_?[A-Za-z_][A-Za-z0-9_]*)[^,]*,\\s*(_?[A-Za-z_][A-Za-z0-9_]*)").search(lines[index])
            if fm == null or not t.contains("request_completed.connect(%s)" % fm.get_string(1)):
                continue
            var result_name := fm.get_string(2)
            var code_name := fm.get_string(3)
            var body := ""
            for j in range(index + 1, lines.size()):
                if lines[j].begins_with("func ") or (lines[j].strip_edges() != "" and not lines[j].begins_with(" ") and not lines[j].begins_with("\t")):
                    break
                body += lines[j] + "\n"
            var uses := (not result_name.begins_with("_") and RegEx.create_from_string("\\b%s\\b" % result_name).search(body) != null) or (not code_name.begins_with("_") and RegEx.create_from_string("\\b%s\\b" % code_name).search(body) != null)
            if not uses:
                issues.append(_issue("warning", "unhandled_result", str(path), index + 1, "%s ignores the request result and response code; offline or error responses are treated as success." % fm.get_string(1), "Return early unless result == HTTPRequest.RESULT_SUCCESS and the response code is 2xx, and show the player an offline state."))
    var preview: Array = []
    var profile: Dictionary = options.get("profile_data", {})
    if not profile.is_empty():
        for r in profile.get("rules", []):
            if str(r.get("fault", "")) not in FAULTS:
                issues.append(_issue("error", "bad_profile", "profile", 0, "Unknown fault '%s'." % r.get("fault", ""), "Use one of: %s." % ", ".join(FAULTS)))
        var list: Array = urls.keys()
        list.sort()
        for u in list:
            preview.append({"url": u, "first_requests": range(5).map(func(i): return decide(profile, u, i)["fault"])})
    return _finish({"urls": urls.size()}, issues, {"preview": preview})


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
    var lines: Array = ["# Offline and Poor-Connection Test Harness", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
