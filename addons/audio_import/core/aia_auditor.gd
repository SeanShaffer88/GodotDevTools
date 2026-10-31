## Audio Import Settings Auditor - import settings vs role.
## Reads Godot 4 .import files for WAV, Ogg Vorbis and MP3. Roles come from
## path patterns (music, sfx). WAV loop_mode 0 (detect) counts as looping
## only when the WAV has a smpl loop chunk. WAV length comes from the source
## file header.
extends RefCounted

const EXTS: Array[String] = ["import"]
const DEFAULTS := {"music_pattern": "/music/", "sfx_pattern": "/sfx/", "max_wav_seconds": 10.0}


func run(input: String = "res://", options: Dictionary = {}) -> Dictionary:
    if DirAccess.open(input) == null:
        return _fail(input, "Cannot open scan directory.", "Provide an existing readable project directory.")
    var paths: Array = []
    _walk(input, paths)
    paths.sort()
    var texts := {}
    var sources := {}
    for path in paths:
        var src := str(path).trim_suffix(".import")
        if src.get_extension().to_lower() not in ["wav", "ogg", "mp3"]:
            continue
        texts[path] = FileAccess.get_file_as_string(path)
        if src.get_extension().to_lower() == "wav" and FileAccess.file_exists(src):
            var f := FileAccess.open(src, FileAccess.READ)
            sources[src] = wav_info(f.get_buffer(min(f.get_length(), 1 << 20)), f.get_length())
    var merged: Dictionary = options.duplicate()
    merged["sources"] = sources
    return analyze(texts, merged)


## {seconds, has_loop} from a WAV header (and a smpl chunk if present).
func wav_info(b: PackedByteArray, total_size: int) -> Dictionary:
    var info := {"seconds": 0.0, "has_loop": false}
    if b.size() < 12 or b.slice(0, 4).get_string_from_ascii() != "RIFF":
        return info
    var pos := 12
    var byte_rate := 0
    while pos + 8 <= b.size():
        var id := b.slice(pos, pos + 4).get_string_from_ascii()
        var size := b.decode_u32(pos + 4)
        if id == "fmt ":
            byte_rate = b.decode_u32(pos + 16)
        elif id == "smpl" and pos + 36 + 4 <= b.size():
            info["has_loop"] = b.decode_u32(pos + 36) > 0
        elif id == "data":
            var length: int = min(size, total_size - pos - 8)
            info["seconds"] = float(length) / max(1, byte_rate)
        pos += 8 + size + (size % 2)
    return info


func analyze(texts: Dictionary, options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    var sources: Dictionary = options.get("sources", {})
    var issues: Array = []
    var clips := 0
    for path in texts.keys():
        if texts[path] == null:
            issues.append(_issue("error", "scan_error", str(path), 0, "Cannot read file.", "Check file permissions and retry."))
            continue
        var src := str(path).trim_suffix(".import")
        var ext := src.get_extension().to_lower()
        if ext not in ["wav", "ogg", "mp3"]:
            continue
        clips += 1
        var params := {}
        var in_params := false
        for line in str(texts[path]).split("\n"):
            var s := line.strip_edges()
            if s.begins_with("["):
                in_params = s == "[params]"
            elif in_params and s.contains("="):
                params[s.get_slice("=", 0)] = s.substr(s.find("=") + 1)
        var info: Dictionary = sources.get(src, {"seconds": 0.0, "has_loop": false})
        var loops := false
        if ext == "wav":
            var mode := int(params.get("edit/loop_mode", "0"))
            loops = mode >= 2 or (mode == 0 and info["has_loop"])
        else:
            loops = str(params.get("loop", "false")) == "true"
        var lower := src.to_lower()
        if lower.contains(str(opts["music_pattern"])) and not loops:
            issues.append(_issue("warning", "music_not_looping", src, 0, "Music clip is imported without looping.", "Enable Loop in the Import dock (Ogg/MP3: loop; WAV: Loop Mode Forward) unless the track plays once."))
        if lower.contains(str(opts["sfx_pattern"])) and loops:
            issues.append(_issue("warning", "sfx_looping", src, 0, "Sound effect is imported looping.", "Disable looping in the Import dock unless this is an ambient loop."))
        if ext == "wav" and float(info["seconds"]) > float(opts["max_wav_seconds"]):
            issues.append(_issue("info", "long_wav", src, 0, "%.1f s WAV (%s compression)." % [info["seconds"], ["none", "IMA ADPCM", "QOA"][clampi(int(params.get("compress/mode", "0")), 0, 2)]], "Use Ogg Vorbis for long clips such as music and ambience; keep WAV for short, frequent effects."))
    return _finish({"clips": clips}, issues)


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
    var lines: Array = ["# Audio Import Settings Auditor", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
