## Offline, deliberately narrow Android logcat threadtime crash triage.
## Raw exception messages, stack source paths and log lines are not exported.
extends RefCounted

const MAX_BYTES := 10_000_000
const MAX_EVENTS := 5000
const MAX_FRAME_LINES := 120
const MAX_FRAMES := 3


func run(input: String = "user://android_logcat.txt", options: Dictionary = {}) -> Dictionary:
    var file := FileAccess.open(input, FileAccess.READ)
    if file == null or file.get_length() > MAX_BYTES:
        return _fail(input, "Cannot read the log or it exceeds 10 MB.", "Supply a readable UTF-8 logcat threadtime file under 10 MB.")
    var length := file.get_length()
    var bytes := file.get_buffer(length)
    file.close()
    if bytes.size() != length or bytes.has(0):
        return _fail(input, "Log appears to be binary, UTF-16 or could not be read completely.", "Save logcat output as UTF-8 text.")
    var text := bytes.get_string_from_utf8()
    if text.to_utf8_buffer() != bytes:
        return _fail(input, "Log is not valid UTF-8 text.", "Save logcat output as UTF-8 text.")
    return analyze(text.trim_prefix("\ufeff"), options, input)


func analyze(text: String, options: Dictionary = {}, path: String = "") -> Dictionary:
    var package := str(options.get("package", ""))
    var package_re := _regex("^[A-Za-z][A-Za-z0-9_]*(\\.[A-Za-z][A-Za-z0-9_]*)+$")
    if package != "" and package_re.search(package) == null:
        return _fail(path, "Package filter is not a valid package identifier.", "Supply a package such as com.studio.game without a process suffix.")
    var line_re := _regex("^(?:[0-9]{4}-)?[0-9]{2}-[0-9]{2}\\s+[0-9]{2}:[0-9]{2}:[0-9]{2}\\.[0-9]{3,6}\\s+([0-9]+)\\s+([0-9]+)\\s+([VDIWEF])\\s+([^:]+):\\s?(.*)$")
    var process_re := _regex("^Process:\\s*([A-Za-z][A-Za-z0-9_.]*(?::[A-Za-z0-9_.]+)?),\\s*PID:\\s*([0-9]+)")
    var exception_re := _regex("^(?:Caused by:\\s*)?((?:[A-Za-z_$][A-Za-z0-9_$]*\\.)*(?:[A-Za-z_$][A-Za-z0-9_$]*)?(?:Exception|Error|Throwable))(?::|\\s|$)")
    var frame_re := _regex("^\\s*at\\s+([A-Za-z_$][A-Za-z0-9_$]*(?:\\.[A-Za-z_$<>][A-Za-z0-9_$<>]*)+)\\(")
    var signal_re := _regex("^Fatal signal\\s+([0-9]+)\\s+\\((SIG[A-Z0-9]+)\\)")
    var native_process_re := _regex("\\bpid\\s+[0-9]+\\s+\\(([A-Za-z][A-Za-z0-9_.]*(?::[A-Za-z0-9_.]+)?)\\)")
    var anr_re := _regex("^ANR in\\s+([A-Za-z][A-Za-z0-9_.]*(?::[A-Za-z0-9_.]+)?)")
    var incidents: Array = []
    var open_java := {}
    var supported := 0
    var unsupported := 0
    var dropped := 0
    var lines := text.split("\n", true)
    for index in lines.size():
        var line := str(lines[index]).trim_suffix("\r")
        if line.strip_edges().is_empty():
            continue
        var match_line: RegExMatch = line_re.search(line) if line.length() <= 16384 else null
        if match_line == null:
            unsupported += 1
            continue
        supported += 1
        var pid := match_line.get_string(1)
        var tag := match_line.get_string(4).strip_edges()
        var message := match_line.get_string(5)
        if tag == "AndroidRuntime" and message.begins_with("FATAL EXCEPTION:"):
            open_java.erase(pid)
            if incidents.size() >= MAX_EVENTS:
                dropped += 1
                continue
            var event := {"type": "java", "process": "", "exception": "", "cause": "", "frames": [], "line": index + 1}
            incidents.append(event)
            open_java[pid] = event
        elif tag == "AndroidRuntime" and open_java.has(pid):
            var event: Dictionary = open_java[pid]
            if index + 1 - int(event["line"]) > MAX_FRAME_LINES:
                open_java.erase(pid)
                continue
            var process_match := process_re.search(message)
            var exception_match := exception_re.search(message.strip_edges())
            var frame_match := frame_re.search(message)
            if process_match != null and int(process_match.get_string(2)) == int(pid) and process_match.get_string(1).length() <= 200:
                event["process"] = process_match.get_string(1)
            elif exception_match != null and exception_match.get_string(1).length() <= 240:
                if message.strip_edges().begins_with("Caused by:"):
                    event["cause"] = exception_match.get_string(1)
                elif str(event["exception"]).is_empty():
                    event["exception"] = exception_match.get_string(1)
            elif frame_match != null and event["frames"].size() < MAX_FRAMES and frame_match.get_string(1).length() <= 240:
                event["frames"].append(frame_match.get_string(1))
        elif tag == "libc":
            var signal_match := signal_re.search(message)
            if signal_match != null:
                if incidents.size() >= MAX_EVENTS:
                    dropped += 1
                    continue
                var native_process := native_process_re.search(message)
                var native_name := native_process.get_string(1) if native_process != null and native_process.get_string(1).length() <= 200 else ""
                incidents.append({"type": "native", "process": native_name, "signal": signal_match.get_string(2), "line": index + 1})
        elif tag == "ActivityManager":
            var anr_match := anr_re.search(message)
            if anr_match != null and anr_match.get_string(1).length() <= 200:
                if incidents.size() >= MAX_EVENTS:
                    dropped += 1
                    continue
                incidents.append({"type": "anr", "process": anr_match.get_string(1), "line": index + 1})
    if supported == 0:
        return _fail(path, "No supported threadtime log lines were found.", "Capture UTF-8 text with adb logcat -v threadtime.")
    var groups_by_key := {}
    var selected := 0
    var unattributed := 0
    var incomplete := 0
    for event in incidents:
        var process := str(event["process"])
        if package != "":
            if process == "":
                unattributed += 1
                continue
            if process != package and not process.begins_with(package + ":"):
                continue
        selected += 1
        if event["type"] == "java" and (str(event["exception"]).is_empty() or event["frames"].is_empty()):
            incomplete += 1
        var key := _key(event)
        if not groups_by_key.has(key):
            var group: Dictionary = event.duplicate(true)
            group["count"] = 0
            group["signature"] = key
            group["hint"] = _hint(group)
            groups_by_key[key] = group
        groups_by_key[key]["count"] += 1
    var keys := groups_by_key.keys()
    keys.sort()
    var groups: Array = []
    var issues: Array = []
    for key in keys:
        var group: Dictionary = groups_by_key[key]
        groups.append(group)
        var label := "Java fatal exception" if group["type"] == "java" else ("native fatal signal" if group["type"] == "native" else "application not responding")
        var detail := str(group.get("exception", "")) if group["type"] == "java" else str(group.get("signal", ""))
        var who := str(group["process"]) if str(group["process"]) != "" else "unknown process"
        var message := "%d %s record(s) for %s%s." % [group["count"], label, who, " (" + detail + ")" if detail != "" else ""]
        var kind := "java_crash" if group["type"] == "java" else ("native_crash" if group["type"] == "native" else "anr")
        issues.append(_issue("error", kind, path, int(group["line"]), message, str(group["hint"])))
    if selected == 0:
        issues.append(_issue("info", "no_matching_crashes", path, 0, "No recognized crash records matched the supplied filter.", "This limited parser cannot prove the app is crash-free; review the original log."))
    if unattributed > 0:
        issues.append(_issue("warning", "unattributed_crashes", path, 0, "%d crash record(s) lacked a recognized process and were excluded by the package filter." % unattributed, "Review the original log or rerun without the package filter."))
    if incomplete > 0:
        issues.append(_issue("info", "incomplete_java_trace", path, 0, "%d selected Java crash record(s) lacked an exception class or recognized frames." % incomplete, "Capture the complete threadtime log and inspect the original trace."))
    if unsupported > 0:
        issues.append(_issue("info", "unsupported_lines", path, 0, "%d nonempty line(s) were not threadtime records and were ignored." % unsupported, "Review omitted lines, especially multiline or tombstone output, in the original log."))
    if dropped > 0:
        issues.append(_issue("warning", "event_limit", path, 0, "%d crash headers exceeded the %d-record limit." % [dropped, MAX_EVENTS], "Split the log into smaller files and review each one."))
    return {"summary": {"supported_lines": supported, "unsupported_lines": unsupported, "recognized_records": incidents.size(), "matched_records": selected, "groups": groups.size(), "issues": issues.size()}, "groups": groups, "issues": issues}


func _regex(pattern: String) -> RegEx:
    var expression := RegEx.new()
    expression.compile(pattern)
    return expression


func _key(event: Dictionary) -> String:
    var parts: Array = [str(event["type"]), str(event["process"])]
    if event["type"] == "java":
        parts.append(str(event["exception"]))
        parts.append(str(event["cause"]))
        parts.append_array(event["frames"])
    elif event["type"] == "native":
        parts.append(str(event["signal"]))
    return "|".join(parts)


func _hint(event: Dictionary) -> String:
    if event["type"] == "native":
        return "Reproduce on the affected ABI and symbolicate the native tombstone with matching unstripped libraries."
    if event["type"] == "anr":
        return "Inspect the main-thread trace and look for blocking work or deadlocks; confirm the actual cause."
    var classes := str(event.get("exception", "")) + " " + str(event.get("cause", ""))
    if classes.contains("OutOfMemoryError"):
        return "Inspect memory use and allocations around the crash; the log alone does not establish a leak."
    if classes.contains("UnsatisfiedLinkError"):
        return "Review native library packaging and enabled ABIs for the affected device."
    if classes.contains("SecurityException"):
        return "Review the operation, manifest and runtime permission flow on the affected Android version."
    if classes.contains("NullPointerException"):
        return "Use the full stack trace and reproduction steps to inspect the null value at the failing call."
    return "Inspect the original complete stack trace and reproduce with the same app version and device."


func _issue(severity: String, kind: String, path: String, line: int, message: String, fix: String) -> Dictionary:
    return {"severity": severity, "kind": kind, "path": path, "line": line, "message": message, "fix": fix}


func _fail(path: String, message: String, fix: String) -> Dictionary:
    return {"summary": {"supported_lines": 0, "unsupported_lines": 0, "recognized_records": 0, "matched_records": 0, "groups": 0, "issues": 1}, "groups": [], "issues": [_issue("error", "bad_input", path, 0, message, fix)]}


func to_json(result: Dictionary) -> String:
    return JSON.stringify(result, "  ")


func to_markdown(result: Dictionary) -> String:
    var lines: Array[String] = ["# Android Logcat Crash Triage", "", "Summary: " + str(result["summary"]), "", "## Crash groups"]
    for group in result.get("groups", []):
        lines.append("- **%s** × %d: `%s` — %s" % [group["type"], group["count"], group["signature"], group["hint"]])
    lines.append("\n## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
