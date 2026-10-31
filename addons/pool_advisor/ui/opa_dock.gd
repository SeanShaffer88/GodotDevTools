@tool
extends VBoxContainer
const Core := preload("res://addons/pool_advisor/core/opa_advisor.gd")
var _counts_path: LineEdit
var _output: RichTextLabel

func _init() -> void:
    name = "Pool Advisor"
    custom_minimum_size = Vector2(320, 260)
    var row := HBoxContainer.new()
    var label := Label.new()
    label.text = "Counts file"
    label.tooltip_text = "Optional JSON written by the runtime counter (user://pool_counts.json). Leave empty for static analysis only."
    _counts_path = LineEdit.new()
    _counts_path.placeholder_text = "optional, e.g. user://pool_counts.json"
    _counts_path.tooltip_text = label.tooltip_text
    _counts_path.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(label)
    row.add_child(_counts_path)
    add_child(row)
    var button := Button.new()
    button.text = "Find pool candidates"
    button.tooltip_text = "Read every .gd and .tscn under res:// (addons and reports skipped), find instantiate() calls and rank pool candidates. Read-only; never edits code."
    button.pressed.connect(_on_run)
    add_child(button)
    _output = RichTextLabel.new()
    _output.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _output.selection_enabled = true
    _output.tooltip_text = "Spawned scenes ranked by score, then findings with a suggested fix."
    _output.text = "Scan to rank spawned scenes as pool candidates. See the addon README for scoring."
    add_child(_output)

func _on_run() -> void:
    var counts := {}
    var path := _counts_path.text.strip_edges()
    if path != "":
        var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
        if typeof(parsed) != TYPE_DICTIONARY:
            _output.text = "Counts file missing or not a JSON object: " + path
            return
        counts = parsed
    var result: Dictionary = Core.new().run("res://", counts)
    var lines: Array[String] = ["Summary: " + str(result["summary"])]
    for scene in result["scenes"]:
        lines.append("%s - score %d, %d site(s)%s" % [scene["scene"], scene["score"], scene["sites"].size(), ", self-frees" if scene["self_frees"] else ""])
    for issue in result["issues"]:
        lines.append("[%s] %s:%d %s - %s Fix: %s" % [issue["kind"], issue["path"], issue["line"], issue["function"], issue["message"], issue["fix"]])
    _output.text = "\n".join(lines)
