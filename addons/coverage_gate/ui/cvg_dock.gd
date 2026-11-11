@tool
extends VBoxContainer
## Coverage Gate dock. Thin shell over core/; estimate only, read-only.
const Core := preload("res://addons/coverage_gate/core/cvg_coverage.gd")
var _input: LineEdit
var _output: RichTextLabel

func _init() -> void:
	name = "Coverage Gate"
	custom_minimum_size = Vector2(320, 260)
	_input = LineEdit.new()
	_input.text = "res://demo/coverage_gate"
	_input.tooltip_text = "Folder with .gd files to estimate coverage for. Tests are searched in res://tests."
	add_child(_input)
	var button := Button.new()
	button.text = "Estimate coverage"
	button.tooltip_text = "Estimate covered functions from test evidence. This is an estimate, not measured line coverage."
	button.pressed.connect(_on_run)
	add_child(button)
	_output = RichTextLabel.new()
	_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_output.selection_enabled = true
	_output.tooltip_text = "Estimated percent, function counts and any below-threshold finding. See the addon README."
	_output.text = "Estimate GDScript coverage from test evidence."
	add_child(_output)

func _on_run() -> void:
	var result: Dictionary = Core.new().run(_input.text.strip_edges(), {})
	var lines: Array[String] = ["Summary: " + str(result["summary"])]
	for issue in result["issues"]:
		lines.append("[%s] %s - %s" % [issue["kind"], issue["message"], issue["fix"]])
	_output.text = "\n".join(lines)
