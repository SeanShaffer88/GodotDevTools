## Analyze resolved touch-target rectangles in a single screen-space snapshot.
## No scenes, project scripts or device connections are executed by this core.
extends RefCounted

const MAX_BYTES := 5_000_000
const MAX_TARGETS := 500
const MAX_PAIR_FINDINGS := 2000


func run(input: String = "user://touch_snapshot.json", options: Dictionary = {}) -> Dictionary:
    var file := FileAccess.open(input, FileAccess.READ)
    if file == null or file.get_length() > MAX_BYTES:
        return _fail(input, "Cannot read the snapshot or it exceeds 5 MB.", "Supply a readable touch snapshot JSON under 5 MB.")
    var length := file.get_length()
    var bytes := file.get_buffer(length)
    file.close()
    if bytes.size() != length or bytes.has(0):
        return _fail(input, "Snapshot is binary or could not be read completely.", "Supply UTF-8 JSON without binary data.")
    var text := bytes.get_string_from_utf8()
    if text.to_utf8_buffer() != bytes:
        return _fail(input, "Snapshot is not valid UTF-8 text.", "Supply UTF-8 JSON without binary data.")
    var parser := JSON.new()
    if parser.parse(text.trim_prefix("\ufeff")) != OK:
        return _fail(input, "Snapshot is not valid JSON.", "Supply a UTF-8 JSON snapshot using the documented schema.")
    return analyze(parser.data, options, input)


func analyze(data: Variant, options: Dictionary = {}, path: String = "") -> Dictionary:
    var min_size: Variant = options.get("min_dp", 48.0)
    var min_gap: Variant = options.get("gap_dp", 8.0)
    if not _number(min_size) or not _number(min_gap) or float(min_size) <= 0.0 or float(min_gap) < 0.0 or float(min_size) > 10000.0 or float(min_gap) > 10000.0:
        return _fail(path, "Touch thresholds must be finite numbers (size > 0, gap >= 0, both <= 10000 dp).", "Choose suitable numeric dp thresholds.")
    if typeof(data) != TYPE_DICTIONARY or not data.has("screen") or typeof(data["screen"]) != TYPE_DICTIONARY or not data.has("targets") or typeof(data["targets"]) != TYPE_ARRAY:
        return _fail(path, "Snapshot must contain screen and targets objects.", "Use the documented snapshot schema or the runtime capture helper.")
    if data.get("version", null) != 1:
        return _fail(path, "Unsupported or missing snapshot version.", "Use snapshot schema version 1.")
    var screen: Dictionary = data["screen"]
    var screen_size: Variant = screen.get("size_px", null)
    var safe_values: Variant = screen.get("safe_area_px", null)
    var dpi: Variant = screen.get("density_dpi", null)
    if not _numeric_array(screen_size, 2) or not _numeric_array(safe_values, 4) or not _number(dpi):
        return _fail(path, "Screen size, safe area or logical density is missing or invalid.", "Supply size_px [width,height], safe_area_px [x,y,width,height] and density_dpi.")
    if float(screen_size[0]) <= 0.0 or float(screen_size[1]) <= 0.0 or float(dpi) <= 0.0 or float(dpi) > 10000.0:
        return _fail(path, "Screen dimensions and density must be positive and finite.", "Capture on a device with valid display metrics.")
    var safe := _rect(safe_values)
    if safe.position.x < 0.0 or safe.position.y < 0.0 or safe.size.x <= 0.0 or safe.size.y <= 0.0 or safe.end.x > float(screen_size[0]) or safe.end.y > float(screen_size[1]):
        return _fail(path, "Safe area must be a positive rectangle inside the screen.", "Provide a valid screen-space safe area for this device and orientation.")
    var skipped_viewports := 0
    if data.has("capture"):
        if typeof(data["capture"]) != TYPE_DICTIONARY:
            return _fail(path, "Capture metadata must be an object.", "Use the documented snapshot schema.")
        var skipped: Variant = data["capture"].get("skipped_other_viewport", 0)
        if not _number(skipped) or float(skipped) < 0.0 or floor(float(skipped)) != float(skipped):
            return _fail(path, "Skipped viewport count must be a non-negative integer.", "Use the runtime capture helper or correct the snapshot metadata.")
        skipped_viewports = int(skipped)
    var targets: Array = data["targets"]
    if targets.size() > MAX_TARGETS:
        return _fail(path, "Snapshot has more than %d targets." % MAX_TARGETS, "Capture a smaller screen or split it into multiple snapshots.")
    var seen := {}
    var ordered: Array = []
    for item in targets:
        if typeof(item) != TYPE_DICTIONARY or typeof(item.get("path", null)) != TYPE_STRING or str(item["path"]).is_empty() or str(item["path"]).length() > 512 or not _numeric_array(item.get("rect_px", null), 4):
            return _fail(path, "A target has an invalid path or rectangle.", "Each target needs a unique path and rect_px [x,y,width,height].")
        if item.has("axis_aligned") and typeof(item["axis_aligned"]) != TYPE_BOOL:
            return _fail(path, "A target has an invalid axis_aligned flag.", "Use true or false for axis_aligned.")
        var target_rect := _rect(item["rect_px"])
        if target_rect.size.x < 0.0 or target_rect.size.y < 0.0 or seen.has(item["path"]):
            return _fail(path, "A target has negative dimensions or a duplicate path.", "Use non-negative dimensions and a unique path for every target.")
        seen[item["path"]] = true
        ordered.append({"path": item["path"], "rect": target_rect, "axis_aligned": item.get("axis_aligned", true)})
    ordered.sort_custom(func(a, b): return str(a["path"]) < str(b["path"]))
    var factor := 160.0 / float(dpi)
    var issues: Array = []
    if ordered.is_empty():
        issues.append(_issue("info", "no_targets", path, "", "", "No eligible targets are present in the snapshot.", "Capture a visible interactive screen or add manually measured targets."))
    if skipped_viewports > 0:
        issues.append(_issue("warning", "viewport_targets_skipped", path, "", "", "%d eligible control(s) in other viewports were not sampled." % skipped_viewports, "Review those viewports separately on-device."))
    var measurements: Array = []
    var comparable: Array = []
    for item in ordered:
        var target: Rect2 = item["rect"]
        var name := str(item["path"])
        if not item["axis_aligned"]:
            issues.append(_issue("warning", "unsupported_transform", path, name, "", "Target is rotated or skewed; its bounding box is not a reliable touch rectangle.", "Review the target on-device or provide a measured axis-aligned hit area."))
            continue
        var width_dp := target.size.x * factor
        var height_dp := target.size.y * factor
        measurements.append({"target": name, "width_dp": snappedf(width_dp, 0.01), "height_dp": snappedf(height_dp, 0.01)})
        comparable.append(item)
        if width_dp < float(min_size) or height_dp < float(min_size):
            issues.append(_issue("warning", "small_target", path, name, "", "Target is %.1f x %.1f dp; the configured minimum is %.1f dp per side." % [width_dp, height_dp, float(min_size)], "Increase the interactive area or adjust the threshold for your design."))
        if target.position.x < safe.position.x or target.position.y < safe.position.y or target.end.x > safe.end.x or target.end.y > safe.end.y:
            issues.append(_issue("warning", "outside_safe_area", path, name, "", "The target rectangle extends beyond the supplied safe area.", "Reposition or inset the interactive area; verify it on the device."))
    var pair_findings := 0
    var omitted := 0
    for i in comparable.size():
        for j in range(i + 1, comparable.size()):
            var a: Rect2 = comparable[i]["rect"]
            var b: Rect2 = comparable[j]["rect"]
            var kind := ""
            var message := ""
            if a.size.x > 0.0 and a.size.y > 0.0 and b.size.x > 0.0 and b.size.y > 0.0 and a.intersects(b):
                kind = "overlap"
                message = "Target rectangles overlap; check which control receives the touch."
            elif float(min_gap) > 0.0:
                var dx: float = maxf(0.0, maxf(a.position.x - b.end.x, b.position.x - a.end.x))
                var dy: float = maxf(0.0, maxf(a.position.y - b.end.y, b.position.y - a.end.y))
                var gap := sqrt(dx * dx + dy * dy) * factor
                if gap < float(min_gap):
                    kind = "close_targets"
                    message = "Target rectangles are %.1f dp apart; the configured gap is %.1f dp." % [gap, float(min_gap)]
            if kind != "":
                if pair_findings < MAX_PAIR_FINDINGS:
                    issues.append(_issue("warning", kind, path, str(comparable[i]["path"]), str(comparable[j]["path"]), message, "Separate the touch areas or confirm their intended event handling."))
                    pair_findings += 1
                else:
                    omitted += 1
    if omitted > 0:
        issues.append(_issue("warning", "pair_findings_truncated", path, "", "", "%d additional target pairs were omitted from this report." % omitted, "Split the capture into smaller screens and review the omitted pairs."))
    return {"summary": {"targets": ordered.size(), "measured": measurements.size(), "issues": issues.size()}, "screen": {"size_px": screen_size, "safe_area_px": safe_values, "density_dpi": dpi}, "thresholds_dp": {"size": min_size, "gap": min_gap}, "measurements": measurements, "issues": issues}


func _number(value: Variant) -> bool:
    return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and absf(float(value)) <= 1000000000.0


func _numeric_array(value: Variant, length: int) -> bool:
    if typeof(value) != TYPE_ARRAY or value.size() != length:
        return false
    for number in value:
        if not _number(number):
            return false
    return true


func _rect(values: Array) -> Rect2:
    return Rect2(float(values[0]), float(values[1]), float(values[2]), float(values[3]))


func _issue(severity: String, kind: String, path: String, target: String, other: String, message: String, fix: String) -> Dictionary:
    var prefix := target
    if other != "":
        prefix += " vs " + other
    if prefix != "":
        prefix += ": "
    return {"severity": severity, "kind": kind, "path": path, "line": 0, "target": target, "other_target": other, "message": prefix + message, "fix": fix}


func _fail(path: String, message: String, fix: String) -> Dictionary:
    return {"summary": {"targets": 0, "measured": 0, "issues": 1}, "measurements": [], "issues": [_issue("error", "bad_input", path, "", "", message, fix)]}


func to_json(result: Dictionary) -> String:
    return JSON.stringify(result, "  ")


func to_markdown(result: Dictionary) -> String:
    var lines: Array[String] = ["# Android Touch and Safe Area Audit", "", "Summary: " + str(result["summary"]), "", "## Findings"]
    for issue in result["issues"]:
        lines.append("- **%s** `%s`: %s %s" % [issue["kind"], issue["path"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
