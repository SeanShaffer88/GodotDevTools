## Offline subtitle timing audit. Supports JSON cues and a documented SRT/WebVTT subset.
extends RefCounted

const DEFAULT_MIN_SECONDS := 1.0
const DEFAULT_MAX_CPS := 20.0
const DEFAULT_MAX_LINE := 42

func run(path: String, options: Dictionary = {}) -> Dictionary:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return _result(0, [_issue("error", "input_error", path, "Cannot read subtitle file.", "Choose a readable subtitle file.")])
    var text := file.get_as_text()
    var extension := path.get_extension().to_lower()
    if extension in ["srt", "vtt"]:
        var parsed := parse_timed_text(text, extension)
        if not parsed["ok"]:
            return _result(0, [_issue("error", "input_error", path, str(parsed["error"]), "Correct the subtitle file and retry.")])
        return analyze({"cues": parsed["cues"]}, options)
    var parser := JSON.new()
    if parser.parse(text) != OK or typeof(parser.data) != TYPE_DICTIONARY:
        return _result(0, [_issue("error", "input_error", path, "Invalid JSON or top-level value is not an object.", "Provide a JSON object with a cues array.")])
    return analyze(parser.data, options)

## Parse a documented text subset; never return partial cues on malformed input.
func parse_timed_text(text: String, format: String) -> Dictionary:
    if format not in ["srt", "vtt"]:
        return {"ok": false, "error": "Unsupported timed-text format."}
    var normalized := text.trim_prefix("\ufeff").replace("\r\n", "\n").replace("\r", "\n")
    var lines := normalized.split("\n")
    var index := 0
    var cues: Array = []
    if format == "vtt":
        if lines.is_empty() or not (lines[0] == "WEBVTT" or lines[0].begins_with("WEBVTT ") or lines[0].begins_with("WEBVTT\t")):
            return {"ok": false, "error": "Missing WEBVTT header."}
        index = 1
        while index < lines.size() and not lines[index].strip_edges().is_empty():
            if lines[index].contains("-->"):
                return {"ok": false, "error": "WEBVTT header must be separated from cues by a blank line."}
            index += 1
    while index < lines.size():
        while index < lines.size() and lines[index].strip_edges().is_empty():
            index += 1
        if index >= lines.size():
            break
        var first := str(lines[index]).strip_edges()
        if format == "vtt" and (first == "NOTE" or first.begins_with("NOTE ") or first.begins_with("NOTE\t") or first == "STYLE" or first == "REGION"):
            index += 1
            while index < lines.size() and not lines[index].strip_edges().is_empty():
                if lines[index].contains("-->"):
                    return {"ok": false, "error": "Missing blank line before cue at line %d." % (index + 1)}
                index += 1
            continue
        if not first.contains("-->"):
            if format == "srt" and not first.is_valid_int():
                return {"ok": false, "error": "Invalid SRT cue identifier at line %d." % (index + 1)}
            index += 1
            if index >= lines.size() or not lines[index].contains("-->"):
                return {"ok": false, "error": "Missing cue timing after identifier at line %d." % index}
        var timing_line := str(lines[index]).strip_edges()
        var parts := timing_line.split("-->")
        if parts.size() != 2:
            return {"ok": false, "error": "Invalid timing at line %d." % (index + 1)}
        var right := str(parts[1]).strip_edges()
        var right_parts := right.replace("\t", " ").split(" ", false)
        if right_parts.is_empty() or (format == "srt" and right_parts.size() != 1):
            return {"ok": false, "error": "Invalid timing or unsupported SRT settings at line %d." % (index + 1)}
        var start := _timestamp(str(parts[0]).strip_edges(), format)
        var end := _timestamp(str(right_parts[0]), format)
        if start < 0.0 or end < 0.0:
            return {"ok": false, "error": "Invalid timestamp at line %d." % (index + 1)}
        index += 1
        var body: Array[String] = []
        while index < lines.size() and not lines[index].strip_edges().is_empty():
            if lines[index].contains("-->"):
                return {"ok": false, "error": "Missing blank line before cue at line %d." % (index + 1)}
            body.append(lines[index])
            index += 1
        cues.append({"start": start, "end": end, "text": "\n".join(body)})
    if cues.is_empty():
        return {"ok": false, "error": "No subtitle cues found."}
    return {"ok": true, "cues": cues}

func _timestamp(value: String, format: String) -> float:
    var regex := RegEx.new()
    if format == "srt":
        regex.compile("^([0-9]{2,}):([0-9]{2}):([0-9]{2}),([0-9]{3})$")
    else:
        regex.compile("^(?:([0-9]{2,}):)?([0-9]{2}):([0-9]{2})\\.([0-9]{3})$")
    var found := regex.search(value)
    if found == null:
        return -1.0
    var hours := int(found.get_string(1)) if found.get_string(1) != "" else 0
    var minutes := int(found.get_string(2))
    var seconds := int(found.get_string(3))
    if minutes >= 60 or seconds >= 60:
        return -1.0
    return hours * 3600.0 + minutes * 60.0 + seconds + int(found.get_string(4)) / 1000.0

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
    var layout := _layout(options)
    if layout.has("error"):
        return _result(0, [_issue("error", "invalid_options", "layout", str(layout["error"]), "Check --font, --font-size, --layout-width, --safe-area and --max-lines.")])
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
        if not layout.is_empty() and not text.strip_edges().is_empty():
            var fit := measure(text, layout)
            if fit["clipped"]:
                issues.append(_issue("warning", "layout_clipped", label, "A word is %.0f px wide; the safe area is %.0f px at size %d." % [fit["widest_word"], layout["box"], layout["size"]], "Shorten or hyphenate the word, or lower the font size."))
            elif int(fit["lines"]) > int(layout["max_lines"]):
                issues.append(_issue("warning", "layout_overflow", label, "Wraps to %d lines in a %.0f px safe area at size %d (limit %d)." % [fit["lines"], layout["box"], layout["size"], layout["max_lines"]], "Split the cue or shorten the text; check it in the game's subtitle box."))
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

## Rendered-layout options -> {font, size, box, max_lines}; {} when not
## requested; {"error": ...} when invalid. Requested by any of font_size,
## font, layout_width, safe_area or max_lines.
func _layout(options: Dictionary) -> Dictionary:
    var keys := ["font_size", "font", "layout_width", "safe_area", "max_lines"]
    if not keys.any(func(k): return options.has(k)):
        return {}
    var size := int(options.get("font_size", 32))
    var width := float(options.get("layout_width", 1920))
    var safe := float(options.get("safe_area", 0.9))
    var max_lines := int(options.get("max_lines", 2))
    if size <= 0 or width <= 0.0 or safe <= 0.0 or safe > 1.0 or max_lines <= 0:
        return {"error": "Layout needs font_size > 0, layout_width > 0, 0 < safe_area <= 1 and max_lines > 0."}
    var font: Font = ThemeDB.fallback_font
    var font_path := str(options.get("font", ""))
    if font_path != "":
        var loaded: Variant = load(font_path) if ResourceLoader.exists(font_path) else null
        if not loaded is Font:
            return {"error": "Font %s could not be loaded." % font_path}
        font = loaded
    return {"font": font, "size": size, "box": width * safe, "max_lines": max_lines}


## Lay text out with the engine's own line breaker (TextParagraph, the
## TextServer path Label uses) inside the safe-area box:
## {lines, clipped, widest_word}. Explicit newlines always break.
func measure(text: String, layout: Dictionary) -> Dictionary:
    var font: Font = layout["font"]
    var size := int(layout["size"])
    var box := float(layout["box"])
    var para := TextParagraph.new()
    para.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND
    para.width = box
    para.add_string(text, font, size)
    var widest := 0.0
    for word in text.replace("\n", " ").split(" ", false):
        widest = maxf(widest, font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
    return {"lines": para.get_line_count(), "clipped": widest > box, "widest_word": widest}


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
