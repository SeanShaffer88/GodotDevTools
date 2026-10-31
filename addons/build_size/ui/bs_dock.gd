@tool
extends VBoxContainer
const Analyzer := preload("res://addons/build_size/core/bs_analyzer.gd")
var _path: LineEdit
var _output: RichTextLabel

func _init() -> void:
    name = "Build Size Explorer"
    custom_minimum_size = Vector2(320, 250)
    _path = LineEdit.new()
    _path.text = "res://demo/build_size"
    _path.tooltip_text = "Unpacked build directory; archive contents are not inspected."
    add_child(_path)
    var button := Button.new()
    button.text = "Analyze directory"
    button.tooltip_text = "Read file sizes without modifying build files."
    button.pressed.connect(_on_run)
    add_child(button)
    _output = RichTextLabel.new()
    _output.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _output.text = "Select an unpacked build directory to inspect."
    add_child(_output)

func _on_run() -> void:
    var op = Analyzer.new()
    var result: Dictionary = op.run(_path.text)
    _output.text = op.to_markdown(result)
