## Offline subtitle timing audit. Input is a JSON object containing a cues array.
extends RefCounted

const DEFAULT_MIN_SECONDS := 1.0
const DEFAULT_MAX_CPS := 20.0
const DEFAULT_MAX_LINE := 42

func run(path: String, options: Dictionary = {}) -> Dictionary:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return _result(0, [_issue("error", "input_error", path, "Cannot read subtitle file.", "Choose a readable JSON file.")])
    var parser := JSON.new()
    if parser.parse(file.get_as_text()) != OK or typeof(parser.data) != TYPE_DICTIONARY:
        return _result(0, [_issue("error", "input_error", path, "Invalid JSON or top-level value is not an object.", "Provide a JSON object with a cues array.")])
    return analyze(parser.data, options)

func analyze(data: Dictionary, options: Dictionary = {}) -> Dictionary:
    var issues: Array = []
    var min_seconds := float(options.get("min_seconds", DEFAULT_MIN_SECONDS))
    var max_cps := float(options.get("max_cps", DEFAULT_MAX_CPS))
    var max_line := int(options.get("max_line", DEFAULT_MAX_LINE))
    var require_speaker := bool(options.get("require_speaker", false))
    if min_seconds < 0.0 or max_cps <= 0.0 or max_line <= 0:
        return _result(0, [_issue("error", "invalid_options", "options", "Thresholds must be positive (minimum duration may be zero).", "Adjust min_seconds, max_cps and max_line.")])
    if not data.has("cues") or typeof(data["cues"]) != TYPE_ARRAY:
        return _result(0, [_issue("error", "input_error", "cues", "Expected a cues array.", "Add a cues array to the subtitle JSON object.")])
    var cues: Array = data["cues"]
    var valid: Array = []
    for index in range(cues.size()):
        var label := "cues[%d]" % index
        if typeof(cues[index]) != TYPE_DICTIONARY:
            issues.append(_issue("error", "invalid_cue", label, "Cue must be an object.", "Provide start, end and text fields."))
            continue
        var cue: Dictionary = cues[index]
        if not _number(cue.get("start")) or not _number(cue.get("end")) or typeof(cue.get("text")) != TYPE_STRING:
            issues.append(_issue("error", "invalid_cue", label, "Cue requires numeric start/end and string text.", "Correct the cue fields."))
            continue
        var start := float(cue["start"])
        var end := float(cue["end"])
        if start < 0.0 or end <= start:
            issues.append(_issue("error", "invalid_timing", label, "Cue must start at or after zero and end after it starts.", "Correct start and end times in seconds."))
            continue
        var text := str(cue["text"])
        var duration := end - start
        valid.append({"index": index, "start": start, "end": end})
        if text.strip_edges().is_empty():
            issues.append(_issue("warning", "empty_text", label, "Subtitle text is empty.", "Provide text or remove the cue."))
        if duration < min_seconds:
            issues.append(_issue("warning", "short_duration", label, "Cue lasts %.2f seconds (minimum %.2f)." % [duration, min_seconds], "Lengthen the cue where timing allows."))
        var chars := text.replace("\n", "").length()
        var cps := float(chars) / duration
        if cps > max_cps:
            issues.append(_issue("warning", "reading_speed", label, "Cue has %.1f characters per second (limit %.1f)." % [cps, max_cps], "Shorten the text or extend its display time."))
        for line in text.split("\n"):
            if line.length() > max_line:
                issues.append(_issue("warning", "long_line", label, "A line has %d characters (limit %d)." % [line.length(), max_line], "Reword or reflow the subtitle and test the actual display."))
                break
        if require_speaker and str(cue.get("speaker", "")).strip_edges().is_empty():
            issues.append(_issue("warning", "missing_speaker", label, "Cue has no speaker label.", "Add a speaker label where identification is needed."))
    valid.sort_custom(func(a, b): return a["start"] < b["start"] if a["start"] != b["start"] else a["index"] < b["index"])
    var furthest_end := -1.0
    var furthest_index := -1
    for cue in valid:
        if float(cue["start"]) < furthest_end:
            issues.append(_issue("warning", "overlap", "cues[%d]" % cue["index"], "Cue overlaps cues[%d]." % furthest_index, "Review simultaneous dialogue or adjust timing."))
        if float(cue["end"]) > furthest_end:
            furthest_end = float(cue["end"])
            furthest_index = int(cue["index"])
    return _result(cues.size(), issues)

func _number(value) -> bool:
    return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT

func _issue(severity: String, kind: String, path: String, message: String, fix: String) -> Dictionary:
    return {"severity": severity, "kind": kind, "path": path, "message": message, "fix": fix}

func _result(count: int, issues: Array) -> Dictionary:
    return {"summary": {"cues": count, "issues": issues.size()}, "issues": issues}

func to_json(result: Dictionary) -> String:
    return JSON.stringify(result, "  ")

func to_markdown(result: Dictionary) -> String:
    var lines: Array[String] = ["# Subtitle Timing and Readability Audit", "", "Summary: " + str(result["summary"]), "", "## Findings"]
    for issue in result["issues"]:
        lines.append("- **%s** `%s`: %s %s" % [issue["kind"], issue["path"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
