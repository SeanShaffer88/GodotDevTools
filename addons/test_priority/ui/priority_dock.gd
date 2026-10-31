@tool
extends VBoxContainer
const Core := preload("res://addons/test_priority/core/priority_plan.gd")
var _first: LineEdit
var _second: LineEdit
var _output: RichTextLabel

func _init() -> void:
    name = "Regression Test Prioritizer"
    custom_minimum_size = Vector2(320, 250)
    _first = LineEdit.new()
    _first.text = "res://demo/test_priority/mapping.json"
    _first.tooltip_text = "First input JSON path; see addon README for format."
    add_child(_first)
    _second = LineEdit.new()
    _second.text = "res://demo/test_priority/changes.json"
    _second.tooltip_text = "Second input JSON path; see addon README for format."
    add_child(_second)
    var button := Button.new()
    button.text = "Run check"
    button.tooltip_text = "Analyze the input files without changing them."
    button.pressed.connect(_on_run)
    add_child(button)
    _output = RichTextLabel.new()
    _output.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _output.text = "Enter both JSON input paths and run the check."
    add_child(_output)

func _on_run() -> void:
    var op = Core.new()
    _output.text = op.to_markdown(op.run(_first.text, _second.text))
