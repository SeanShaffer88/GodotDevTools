@tool
extends VBoxContainer
func _init() -> void:
	name = "Bad"
	var button := Button.new()
	button.text = "Run"
	add_child(button)
