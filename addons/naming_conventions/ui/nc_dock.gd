@tool
extends VBoxContainer
const Audit := preload("res://addons/naming_conventions/core/nc_audit.gd")
var _path: LineEdit
var _pattern: LineEdit
var _output: RichTextLabel
var _symbols: CheckBox

func _init() -> void:
    name = "Naming Conventions"
    custom_minimum_size = Vector2(320, 250)
    _path = LineEdit.new()
    _path.text = "res://"
    _path.tooltip_text = "Directory to scan; hidden, addon and report directories are skipped."
    add_child(_path)
    _pattern = LineEdit.new()
    _pattern.text = Audit.DEFAULT_PATTERN
    _pattern.tooltip_text = "Godot regex applied to each directory name and file basename."
    add_child(_pattern)
    _symbols = CheckBox.new()
    _symbols.text = "Check scene nodes, signals and groups"
    _symbols.tooltip_text = "Static text scan using default symbol patterns. See README for limits and CLI overrides."
    add_child(_symbols)
    var button := Button.new()
    button.text = "Audit names"
    button.tooltip_text = "Check names without renaming or editing any project files."
    button.pressed.connect(_on_run)
    add_child(button)
    _output = RichTextLabel.new()
    _output.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _output.text = "Set a directory and regular expression, then audit."
    add_child(_output)

func _on_run() -> void:
    var result: Dictionary = Audit.new().run(_path.text, _pattern.text, _symbols.button_pressed)
    var lines: Array[String] = ["Summary: " + str(result["summary"])]
    for issue in result["issues"]:
        lines.append("[%s] %s — %s" % [issue["kind"], issue["path"], issue["message"]])
    _output.text = "\n".join(lines)
