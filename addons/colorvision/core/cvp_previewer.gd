## Color-Vision and Contrast Previewer - CVD simulation.
## Each colour is linearized (sRGB), multiplied by the Machado, Oliveira and
## Fernandes (2009) matrix for full-severity protanopia, deuteranopia or
## tritanopia, clamped, and converted to CIELAB. Pairs whose CIE76 delta E
## falls below min_delta_e under a simulation (but not in normal vision) are
## reported; pairs already close in normal vision are reported separately.
## Simulated hex values are listed for previewing. A simulation, not a
## substitute for testing with players.
extends RefCounted

const EXTS: Array[String] = ["json"]
func run(input: String = "", options: Dictionary = {}) -> Dictionary:
    var data: Variant = _read_json(input)
    if typeof(data) != TYPE_DICTIONARY:
        return _fail(input, "Input missing or not a JSON object.", "Pass --input=<json> in the format described in the addon README.", "bad_input")
    var result: Dictionary = evaluate(data, options)
    for issue in result["issues"]:
        if issue["path"] == "":
            issue["path"] = input
    return result

const DEFAULTS := {}
const MATRICES := {
    "protanopia": [[0.152286, 1.052583, -0.204868], [0.114503, 0.786281, 0.099216], [-0.003882, -0.048116, 1.051998]],
    "deuteranopia": [[0.367322, 0.860646, -0.227968], [0.280085, 0.672501, 0.047413], [-0.011820, 0.042940, 0.968881]],
    "tritanopia": [[1.255528, -0.076749, -0.178779], [-0.078411, 0.930809, 0.147602], [0.004733, 0.691367, 0.303900]]}


func _lin(v: float) -> float:
    return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)


func _gamma(v: float) -> float:
    return v * 12.92 if v <= 0.0031308 else 1.055 * pow(v, 1.0 / 2.4) - 0.055


func simulate(c: Color, kind: String) -> Array:
    var l := [_lin(c.r), _lin(c.g), _lin(c.b)]
    if kind == "normal":
        return l
    var m: Array = MATRICES[kind]
    var out: Array = []
    for i in range(3):
        out.append(clampf(m[i][0] * l[0] + m[i][1] * l[1] + m[i][2] * l[2], 0.0, 1.0))
    return out


func lab(l: Array) -> Vector3:
    var x: float = (l[0] * 0.4124564 + l[1] * 0.3575761 + l[2] * 0.1804375) / 0.95047
    var y: float = l[0] * 0.2126729 + l[1] * 0.7151522 + l[2] * 0.0721750
    var z: float = (l[0] * 0.0193339 + l[1] * 0.1191920 + l[2] * 0.9503041) / 1.08883
    var f := func(t: float) -> float: return pow(t, 1.0 / 3.0) if t > 0.008856 else 7.787 * t + 16.0 / 116.0
    var fx: float = f.call(x)
    var fy: float = f.call(y)
    var fz: float = f.call(z)
    return Vector3(116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz))


func evaluate(data: Dictionary, options: Dictionary = {}) -> Dictionary:
    var colors: Variant = data.get("colors")
    if typeof(colors) != TYPE_DICTIONARY or colors.size() < 2:
        return _fail("", "Need a colors object with at least two named colours.", "See the README for the format.", "bad_input")
    var min_de := float(data.get("min_delta_e", 10.0))
    var names: Array = colors.keys()
    for n in names:
        if not Color.html_is_valid(str(colors[n])):
            return _fail("", "Colour %s is not a valid #hex." % n, "Use #rrggbb.", "bad_input")
    var issues: Array = []
    var preview := {}
    for n in names:
        preview[n] = {}
        for kind in ["protanopia", "deuteranopia", "tritanopia"]:
            var s := simulate(Color.html(str(colors[n])), kind)
            preview[n][kind] = "#" + Color(_gamma(s[0]), _gamma(s[1]), _gamma(s[2])).to_html(false)
    for i in range(names.size()):
        for j in range(i + 1, names.size()):
            var a := Color.html(str(colors[names[i]]))
            var b := Color.html(str(colors[names[j]]))
            var normal: float = lab(simulate(a, "normal")).distance_to(lab(simulate(b, "normal")))
            if normal < min_de:
                issues.append(_issue("warning", "indistinct_normal", "", 0, "%s and %s are only %.1f delta E apart even with typical colour vision." % [names[i], names[j], normal], "Separate them in lightness, not only hue."))
                continue
            for kind in ["protanopia", "deuteranopia", "tritanopia"]:
                var de: float = lab(simulate(a, kind)).distance_to(lab(simulate(b, kind)))
                if de < min_de:
                    issues.append(_issue("warning", "indistinct_under_cvd", "", 0, "%s and %s are %.1f delta E apart under simulated %s (normal %.1f)." % [names[i], names[j], de, kind, normal], "Add a second cue (icon, pattern, label) or separate them in lightness."))
    return _finish({"colors": names.size(), "pairs": names.size() * (names.size() - 1) / 2}, issues, {"preview": preview})


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
    var lines: Array = ["# Color-Vision and Contrast Previewer", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
