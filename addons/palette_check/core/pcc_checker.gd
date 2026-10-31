## Colour Palette Consistency Checker - delta E against a palette.
## Collects Color(r, g, b[, a]) literals and "#rrggbb" strings, converts each
## from sRGB to CIELAB (D65), and finds the nearest palette colour by CIE76
## delta E. Colours beyond the allowed distance are reported. Alpha is
## ignored; fully transparent colours and the ignore list are skipped.
extends RefCounted

const EXTS: Array[String] = ["tscn", "tres", "gd"]
const DEFAULTS := {"palette": "res://palette.json"}

var _color_re := RegEx.create_from_string("Color\\(\\s*([0-9.eE+-]+)\\s*,\\s*([0-9.eE+-]+)\\s*,\\s*([0-9.eE+-]+)(?:\\s*,\\s*([0-9.eE+-]+))?\\s*\\)")
var _hex_re := RegEx.create_from_string("\"#([0-9a-fA-F]{6})\"")


func run(input: String = "res://", options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    var pal: Variant = _read_json(str(opts["palette"]))
    if typeof(pal) != TYPE_DICTIONARY or typeof(pal.get("colors")) != TYPE_ARRAY or pal["colors"].is_empty():
        return _fail(str(opts["palette"]), "Palette missing or without a colors array.", "Create a palette JSON: {\"colors\": [\"#1d2b53\"], \"max_delta_e\": 6}.", "bad_palette")
    if DirAccess.open(input) == null:
        return _fail(input, "Cannot open scan directory.", "Provide an existing readable project directory.")
    var paths: Array = []
    _walk(input, paths)
    paths.sort()
    var texts := {}
    for p in paths:
        texts[p] = FileAccess.get_file_as_string(p)
    return analyze(texts, {"palette_data": pal})


func lab(c: Color) -> Vector3:
    var rgb := [c.r, c.g, c.b].map(func(v): return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4))
    var x: float = (rgb[0] * 0.4124564 + rgb[1] * 0.3575761 + rgb[2] * 0.1804375) / 0.95047
    var y: float = rgb[0] * 0.2126729 + rgb[1] * 0.7151522 + rgb[2] * 0.0721750
    var z: float = (rgb[0] * 0.0193339 + rgb[1] * 0.1191920 + rgb[2] * 0.9503041) / 1.08883
    var f := func(t: float) -> float: return pow(t, 1.0 / 3.0) if t > 0.008856 else 7.787 * t + 16.0 / 116.0
    var fx: float = f.call(x)
    var fy: float = f.call(y)
    var fz: float = f.call(z)
    return Vector3(116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz))


func analyze(texts: Dictionary, options: Dictionary = {}) -> Dictionary:
    var pal: Dictionary = options.get("palette_data", {})
    var colors: Array = pal.get("colors", [])
    var max_de := float(pal.get("max_delta_e", 6.0))
    var ignore: Array = pal.get("ignore", []).map(func(h): return str(h).to_lower())
    var palette: Array = []
    for h in colors:
        if not Color.html_is_valid(str(h)):
            return _fail("palette", "Invalid palette colour %s." % h, "Use #rrggbb values.", "bad_palette")
        palette.append([str(h), lab(Color.html(str(h)))])
    var issues: Array = []
    var checked := 0
    for path in texts.keys():
        if texts[path] == null:
            issues.append(_issue("error", "scan_error", str(path), 0, "Cannot read file.", "Check file permissions and retry."))
            continue
        var lines := str(texts[path]).split("\n")
        for index in range(lines.size()):
            var found: Array = []
            for m in _color_re.search_all(lines[index]):
                var a := 1.0 if m.get_string(4) == "" else float(m.get_string(4))
                if a > 0.0:
                    found.append(Color(float(m.get_string(1)), float(m.get_string(2)), float(m.get_string(3))))
            for m in _hex_re.search_all(lines[index]):
                found.append(Color.html(m.get_string(1)))
            for c in found:
                var hex: String = "#" + c.to_html(false).to_lower()
                if hex in ignore:
                    continue
                checked += 1
                var lc: Vector3 = lab(c)
                var best := INF
                var best_hex := ""
                for p in palette:
                    var d: float = lc.distance_to(p[1])
                    if d < best:
                        best = d
                        best_hex = p[0]
                if best > max_de:
                    issues.append(_issue("warning", "off_palette", str(path), index + 1, "%s is %.1f delta E from the nearest palette colour %s." % [hex, best, best_hex], "Use %s (or another palette colour), or add this colour to the palette." % best_hex))
    return _finish({"colours_checked": checked, "palette": palette.size()}, issues)


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
    var lines: Array = ["# Colour Palette Consistency Checker", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
