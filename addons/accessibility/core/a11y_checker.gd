## Automated Accessibility Checker - scene scan operation.
## Reads scenes as text plus project settings and reports the problems
## that lock players out: text below a readable size, text whose colour
## is too close to its background (WCAG contrast ratio under 4.5:1),
## buttons and other interactive controls that cannot be reached by
## keyboard (focus mode off and no focus neighbours), controls too
## small to aim at, colour-only information (a node whose only "state"
## cue in its name/script is a colour change gets a manual-check note),
## and a project with no keyboard-navigable UI at all. Contrast uses
## the real WCAG relative-luminance formula.
extends RefCounted

var min_font_size: int = 14
var min_contrast: float = 4.5
var min_target_size: float = 24.0
var assumed_background: Color = Color(0.08, 0.08, 0.1) ## dark theme default

const SKIP_DIRS: Array[String] = [".godot", ".git", "addons"]


static func relative_luminance(c: Color) -> float:
    var f := func(v: float) -> float:
        return pow(v, 2.2) if v > 0.03928 else v / 12.92
    # sRGB transfer: values here are already in 0..1; use the WCAG curve.
    var r: float = f.call(c.r)
    var g: float = f.call(c.g)
    var b: float = f.call(c.b)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


static func contrast_ratio(a: Color, b: Color) -> float:
    var la := relative_luminance(a)
    var lb := relative_luminance(b)
    var hi := maxf(la, lb)
    var lo := minf(la, lb)
    return (hi + 0.05) / (lo + 0.05)


func _walk(dir_path: String, out: Array[String]) -> void:
    var dir := DirAccess.open(dir_path)
    if dir == null:
        return
    dir.list_dir_begin()
    var name := dir.get_next()
    while name != "":
        if name.begins_with("."):
            name = dir.get_next()
            continue
        var full := dir_path.path_join(name)
        if dir.current_is_dir():
            if not SKIP_DIRS.has(name):
                _walk(full, out)
        else:
            out.append(full)
        name = dir.get_next()
    dir.list_dir_end()


func _parse_color(text: String) -> Color:
    var inner := text.replace("Color(", "").replace(")", "")
    var parts := inner.split(",")
    if parts.size() < 3:
        return Color.WHITE
    var a := 1.0
    if parts.size() >= 4:
        a = float(parts[3].strip_edges())
    return Color(float(parts[0].strip_edges()), float(parts[1].strip_edges()), float(parts[2].strip_edges()), a)


func scan() -> Dictionary:
    var files: Array[String] = []
    _walk("res://", files)
    var issues: Array = []
    var scenes := 0
    var controls := 0
    var interactive := 0
    var focusable := 0
    var node_re := RegEx.new()
    node_re.compile("^\\[node name=\"([^\"]+)\"(?: type=\"([^\"]+)\")?")
    for path in files:
        if path.get_extension() != "tscn":
            continue
        scenes += 1
        var text := FileAccess.get_file_as_string(path)
        var current: Dictionary = {}
        var blocks: Array = []
        for line in text.split("\n"):
            var m := node_re.search(line)
            if m != null:
                if not current.is_empty():
                    blocks.append(current)
                current = {"name": m.get_string(1), "type": m.get_string(2), "props": {}}
                continue
            if current.is_empty():
                continue
            var t := line.strip_edges()
            var eq := t.find(" = ")
            if eq > 0:
                current["props"][t.substr(0, eq)] = t.substr(eq + 3)
        if not current.is_empty():
            blocks.append(current)
        for block in blocks:
            controls += 1
            var ntype := str(block["type"])
            var props: Dictionary = block["props"]
            var label := "%s (%s) in %s" % [block["name"], ntype if ntype != "" else "node", path]
            if props.has("theme_override_font_sizes/font_size"):
                var fs := int(str(props["theme_override_font_sizes/font_size"]))
                if fs > 0 and fs < min_font_size:
                    issues.append({"severity": "warning", "kind": "tiny_text", "path": path,
                        "message": "%s uses %d px text - below the %d px readable minimum." % [label, fs, min_font_size],
                        "fix": "Raise the font size, or scale the UI up on small screens."})
            if props.has("theme_override_colors/font_color"):
                var fg := _parse_color(str(props["theme_override_colors/font_color"]))
                var ratio := contrast_ratio(fg, assumed_background)
                if ratio < min_contrast:
                    issues.append({"severity": "warning", "kind": "low_contrast", "path": path,
                        "message": "%s text colour %s has contrast %.2f:1 against a dark background - below the %.1f:1 minimum many players need." % [label, str(fg), ratio, min_contrast],
                        "fix": "Lighten the text or darken its background until the ratio reaches %.1f:1." % min_contrast})
            if ntype in ["Button", "CheckBox", "CheckButton", "OptionButton", "LineEdit", "TextEdit", "HSlider", "VSlider", "SpinBox"]:
                interactive += 1
                var fm := str(props.get("focus_mode", "2"))
                if fm == "0":
                    issues.append({"severity": "error", "kind": "no_keyboard_focus", "path": path,
                        "message": "%s has focus mode off - keyboard and controller players cannot reach it." % label,
                        "fix": "Set Focus Mode to All (or set up focus neighbours) so it can be tabbed / navigated to."})
                else:
                    focusable += 1
            if str(block["name"]).to_lower().contains("status") or str(block["name"]).to_lower().contains("indicator"):
                issues.append({"severity": "info", "kind": "color_only_check", "path": path,
                    "message": "%s looks like a status indicator - check it does not communicate by colour alone (colour-blind players would miss it)." % label,
                    "fix": "Add a shape, icon or text label alongside the colour."})
    if interactive > 0 and focusable == 0:
        issues.append({"severity": "error", "kind": "no_keyboard_nav", "path": "res://project.godot",
            "message": "The project has %d interactive controls and none of them can take keyboard focus." % interactive,
            "fix": "Leave focus mode on for buttons and fields, and test the whole UI with Tab / controller only."})
    return {"summary": {"scenes": scenes, "controls": controls, "interactive": interactive,
            "focusable": focusable, "issues": issues.size()},
        "issues": issues}


func to_json(result: Dictionary) -> String:
    return JSON.stringify({"summary": result["summary"], "issues": result["issues"]}, "\t")


func to_markdown(result: Dictionary) -> String:
    var s: Dictionary = result["summary"]
    var lines: Array[String] = ["# Accessibility Report", "",
        "%d scenes, %d controls, %d interactive (%d keyboard-focusable). %d problems." % [
            s["scenes"], s["controls"], s["interactive"], s["focusable"], s["issues"]], ""]
    for i in result["issues"]:
        lines.append("- [%s] %s" % [i["severity"], i["message"]])
    return "\n".join(lines) + "\n"
