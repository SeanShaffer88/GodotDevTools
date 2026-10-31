## Crash and Error Reproduction Packager - local, redacted bundles.
## Collects the tail of a log, Godot version, OS, CPU and locale, the main
## project settings that affect behaviour, and the user's reproduction steps,
## and redacts e-mail addresses, IPv4 addresses, token/key/password values
## and user names in home-directory paths before anything is written. Files
## are written locally (and optionally zipped); the tool has no network code.
## Review the package before sharing it.
extends RefCounted

const EXTS: Array[String] = ["log", "txt"]
const DEFAULTS := {"steps": "", "zip": "", "max_log_bytes": 200000}
const RULES := [
    ["email", "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}", "<email>"],
    ["ipv4", "\\b(?:\\d{1,3}\\.){3}\\d{1,3}\\b", "<ip>"],
    ["secret", "(?i)(token|api[_-]?key|password|passwd|secret|auth)(\\s*[=:]\\s*)[^\\s,;)]+", "$1$2<redacted>"],
    ["home", "(/home/|/Users/|[A-Za-z]:\\\\Users\\\\)[^/\\\\\\s]+", "$1<user>"]]


func redact(text: String) -> Dictionary:
    var counts := {}
    var out := text
    for r in RULES:
        var re := RegEx.create_from_string(r[1])
        var n := re.search_all(out).size()
        if n > 0:
            counts[r[0]] = n
            out = re.sub(out, r[2], true)
    return {"text": out, "counts": counts}


func system_info() -> Dictionary:
    var v := Engine.get_version_info()
    return {"godot": "%s.%s.%s.%s" % [v["major"], v["minor"], v["patch"], v["status"]], "os": OS.get_name(), "os_version": OS.get_version(),
        "cpu": OS.get_processor_name(), "cpu_count": OS.get_processor_count(), "locale": OS.get_locale(), "renderer": str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "")),
        "project": str(ProjectSettings.get_setting("application/config/name", "")), "project_version": str(ProjectSettings.get_setting("application/config/version", ""))}


func run(input: String = "user://logs/godot.log", options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    var log_text: Variant = FileAccess.get_file_as_string(input) if FileAccess.file_exists(input) else null
    var steps := FileAccess.get_file_as_string(str(opts["steps"])) if str(opts["steps"]) != "" and FileAccess.file_exists(str(opts["steps"])) else ""
    var result := evaluate(log_text, steps, system_info(), opts, input)
    if str(opts["zip"]) != "":
        var zip := ZIPPacker.new()
        if zip.open(str(opts["zip"])) == OK:
            for name in result["artifacts"].keys():
                zip.start_file("bug_report/" + name)
                zip.write_file(str(result["artifacts"][name]).to_utf8_buffer())
                zip.close_file()
            zip.close()
            result["summary"]["zip"] = str(opts["zip"])
    return result


func evaluate(log_text: Variant, steps: String, system: Dictionary, options: Dictionary = {}, path: String = "") -> Dictionary:
    var opts := _opts(options)
    var issues: Array = []
    var files := {}
    var counts := {}
    if log_text == null:
        issues.append(_issue("warning", "missing_log", path, 0, "No log at %s." % path, "Enable Project Settings > Debug > File Logging, reproduce the problem, then run again."))
    else:
        var text := str(log_text)
        if text.length() > int(opts["max_log_bytes"]):
            text = text.substr(text.length() - int(opts["max_log_bytes"]))
            issues.append(_issue("info", "log_truncated", path, 0, "Log kept to its last %d characters." % opts["max_log_bytes"], "Raise --max-log-bytes if the cause is earlier."))
        var r := redact(text)
        counts = r["counts"]
        files["log_redacted.txt"] = r["text"]
    var rs := redact(steps)
    for k in rs["counts"].keys():
        counts[k] = int(counts.get(k, 0)) + int(rs["counts"][k])
    files["steps.txt"] = rs["text"] if steps != "" else "(no reproduction steps given)\n"
    files["system.json"] = JSON.stringify(system, "  ")
    var total := 0
    for k in counts.keys():
        total += int(counts[k])
    if total > 0:
        issues.append(_issue("info", "redacted", path, 0, "Redacted %d item(s): %s." % [total, ", ".join(counts.keys().map(func(k): return "%s x%d" % [k, counts[k]]))], "Review the package before sharing; redaction is pattern-based."))
    files["manifest.json"] = JSON.stringify({"files": files.keys(), "redactions": counts, "note": "Generated locally by GodotDevTools; nothing was uploaded."}, "  ")
    return _finish({"files": files.size(), "redactions": total}, issues, {"artifacts": files})


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
    var lines: Array = ["# Crash and Error Reproduction Packager", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
