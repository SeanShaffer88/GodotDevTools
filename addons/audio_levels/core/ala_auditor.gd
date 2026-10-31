## Audio Loudness and Clipping Auditor - PCM WAV analysis.
## Decodes RIFF/WAVE files (8/16/24/32-bit PCM and 32-bit float) and measures
## peak and RMS in dBFS, clipped samples (at or beyond full scale), and DC
## offset (mean sample value). Sample rates are compared with an expected
## rate or the most common rate in the folder. RMS is not perceived loudness
## (LUFS); use it to rank and catch outliers.
extends RefCounted

const EXTS: Array[String] = ["wav"]
func run(input: String = "res://", options: Dictionary = {}) -> Dictionary:
    if DirAccess.open(input) == null:
        return _fail(input, "Cannot open scan directory.", "Provide an existing readable project directory.")
    var paths: Array = []
    _walk(input, paths)
    paths.sort()
    var files := {}
    for path in paths:
        files[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
    return analyze(files, options)

const DEFAULTS := {"expected_rate": 0, "quiet_db": -40.0, "max_samples": 2000000, "hot_db": -1.0, "dc_limit": 0.02}


## Decode one WAV: {rate, channels, bits, seconds, peak, rms, clipped, mean, frames_read} or {error}.
func measure(b: PackedByteArray, max_samples: int = 2000000) -> Dictionary:
    if b.size() < 12 or b.slice(0, 4).get_string_from_ascii() != "RIFF" or b.slice(8, 12).get_string_from_ascii() != "WAVE":
        return {"error": "not a RIFF/WAVE file"}
    var pos := 12
    var fmt := {}
    var data_off := -1
    var data_len := 0
    while pos + 8 <= b.size():
        var id := b.slice(pos, pos + 4).get_string_from_ascii()
        var size := b.decode_u32(pos + 4)
        if id == "fmt ":
            fmt = {"format": b.decode_u16(pos + 8), "channels": b.decode_u16(pos + 10), "rate": b.decode_u32(pos + 12), "bits": b.decode_u16(pos + 22)}
            if int(fmt["format"]) == 0xFFFE and size >= 26:
                fmt["format"] = b.decode_u16(pos + 32)
        elif id == "data":
            data_off = pos + 8
            data_len = min(size, b.size() - data_off)
            break
        pos += 8 + size + (size % 2)
    if fmt.is_empty() or data_off < 0:
        return {"error": "missing fmt or data chunk"}
    var bits := int(fmt["bits"])
    var fmt_code := int(fmt["format"])
    if not ((fmt_code == 1 and bits in [8, 16, 24, 32]) or (fmt_code == 3 and bits == 32)):
        return {"error": "unsupported encoding (format %d, %d-bit); only PCM and 32-bit float" % [fmt_code, bits]}
    var step := bits / 8
    var count := data_len / step
    var n: int = min(count, max_samples)
    var peak := 0.0
    var sum_sq := 0.0
    var sum := 0.0
    var clipped := 0
    for i in range(n):
        var o := data_off + i * step
        var v := 0.0
        if fmt_code == 3:
            v = b.decode_float(o)
        elif bits == 16:
            v = b.decode_s16(o) / 32768.0
        elif bits == 8:
            v = (b[o] - 128) / 128.0
        elif bits == 24:
            var raw := b[o] | (b[o + 1] << 8) | (b[o + 2] << 16)
            if raw & 0x800000:
                raw -= 0x1000000
            v = raw / 8388608.0
        else:
            v = b.decode_s32(o) / 2147483648.0
        var a := absf(v)
        peak = max(peak, a)
        sum_sq += v * v
        sum += v
        if a >= 0.9999:
            clipped += 1
    var channels: int = max(1, int(fmt["channels"]))
    var rate := int(fmt["rate"])
    return {"rate": rate, "channels": channels, "bits": bits, "seconds": snappedf(float(count) / channels / max(1, rate), 0.001),
        "peak_db": _db(peak), "rms_db": _db(sqrt(sum_sq / max(1, n))), "clipped": clipped, "mean": sum / max(1, n), "samples_read": n, "samples_total": count}


func _db(x: float) -> float:
    return -INF if x <= 0.0 else snappedf(20.0 * log(x) / log(10.0), 0.01)


func analyze(files: Dictionary, options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    var issues: Array = []
    var rows := {}
    var rate_votes := {}
    var paths: Array = files.keys()
    paths.sort()
    for path in paths:
        if files[path] == null:
            issues.append(_issue("error", "scan_error", str(path), 0, "Cannot read file.", "Check file permissions and retry."))
            continue
        var m := measure(files[path], int(opts["max_samples"]))
        if m.has("error"):
            issues.append(_issue("warning", "unsupported_wav", str(path), 0, "Cannot analyze: %s." % m["error"], "Convert to PCM WAV to analyze it."))
            continue
        rows[path] = m
        rate_votes[m["rate"]] = int(rate_votes.get(m["rate"], 0)) + 1
        if int(m["clipped"]) > 0:
            issues.append(_issue("warning", "clipping", str(path), 0, "%d samples at full scale (peak %.2f dBFS)." % [m["clipped"], m["peak_db"]], "Re-export with a limiter or lower gain; clipping is baked into the file."))
        elif float(m["peak_db"]) > float(opts["hot_db"]):
            issues.append(_issue("info", "peak_hot", str(path), 0, "Peak %.2f dBFS leaves no headroom." % m["peak_db"], "Leave about 1 dB of headroom so mixing and resampling do not clip."))
        if float(m["rms_db"]) < float(opts["quiet_db"]):
            issues.append(_issue("warning", "too_quiet", str(path), 0, "RMS %.1f dBFS is below %.1f." % [m["rms_db"], opts["quiet_db"]], "Normalize the file or confirm it is meant to be this quiet."))
        if absf(float(m["mean"])) > float(opts["dc_limit"]):
            issues.append(_issue("info", "dc_offset", str(path), 0, "Mean sample value %.3f (DC offset)." % m["mean"], "Apply a DC-offset removal / high-pass filter in your audio editor."))
    var expected := int(opts["expected_rate"])
    if expected == 0 and not rate_votes.is_empty():
        var best := -1
        for r in rate_votes.keys():
            if best < 0 or int(rate_votes[r]) > int(rate_votes[best]) or (int(rate_votes[r]) == int(rate_votes[best]) and int(r) > best):
                best = int(r)
        expected = best
    for path in rows.keys():
        if int(rows[path]["rate"]) != expected:
            issues.append(_issue("info", "rate_mismatch", str(path), 0, "%d Hz, expected %d Hz." % [rows[path]["rate"], expected], "Resample to %d Hz so every clip mixes without runtime resampling." % expected))
    return _finish({"files": rows.size(), "expected_rate": expected}, issues, {"files": rows})


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
    var lines: Array = ["# Audio Loudness and Clipping Auditor", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
