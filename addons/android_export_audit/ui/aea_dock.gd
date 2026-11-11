@tool
extends VBoxContainer
## Read-only editor wrapper; all preset checks are implemented in core/.
const Core := preload("res://addons/android_export_audit/core/aea_audit.gd")
var _input: LineEdit
var _history: LineEdit
var _output: RichTextLabel


func _init() -> void:
    name = "Android Export Audit"
    custom_minimum_size = Vector2(320, 260)
    _input = _field("Preset file", "res://export_presets.cfg", "Godot export_presets.cfg to inspect; it is never changed.")
    _history = _field("History JSON", "", "Optional package-to-last-versionCode JSON; leave empty to skip history comparison.")
    var button := Button.new()
    button.text = "Check Android presets"
    button.tooltip_text = "Review Android package, ABI, format, SDK and release settings without exporting."
    button.pressed.connect(_on_run)
    add_child(button)
    _output = RichTextLabel.new()
    _output.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _output.selection_enabled = true
    _output.tooltip_text = "Preset summary and findings. The tool does not verify signing credentials or store compliance."
    _output.text = "Choose an export preset file, then check it."
    add_child(_output)


func _field(label_text: String, initial: String, tip: String) -> LineEdit:
    var row := HBoxContainer.new()
    var label := Label.new()
    label.text = label_text
    var edit := LineEdit.new()
    edit.text = initial
    edit.tooltip_text = tip
    edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(label)
    row.add_child(edit)
    add_child(row)
    return edit


func _on_run() -> void:
    var options := {}
    if not _history.text.strip_edges().is_empty():
        options["history"] = _history.text.strip_edges()
    var result: Dictionary = Core.new().run(_input.text.strip_edges(), options)
    var lines: Array[String] = ["Summary: " + str(result["summary"])]
    for preset in result.get("presets", []):
        lines.append("%s — %s, version %s, %s" % [preset["name"], preset["package"], preset["version_code"], preset["format"]])
    for issue in result["issues"]:
        lines.append("[%s] %s Fix: %s" % [issue["kind"], issue["message"], issue["fix"]])
    _output.text = "\n".join(lines)
