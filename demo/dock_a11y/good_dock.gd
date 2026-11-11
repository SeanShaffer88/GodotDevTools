@tool
extends VBoxContainer
var _output: RichTextLabel
func _init() -> void:
	name = "Good"
	var button := Button.new()
	button.text = "Run"
	button.tooltip_text = "Run the check."
	button.pressed.connect(_on_run)
	add_child(button)
func _on_run() -> void:
	_output.text = "done"
