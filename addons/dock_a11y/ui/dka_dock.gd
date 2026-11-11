@tool
extends VBoxContainer
## Dock Accessibility Audit dock. Thin shell over core/; read-only.
const Core := preload("res://addons/dock_a11y/core/dka_audit.gd")
var _input: LineEdit
var _output: RichTextLabel

func _init() -> void:
	name = "Dock Accessibility Audit"
	custom_minimum_size = Vector2(320, 260)
	_input = LineEdit.new()
	_input.text = "res://demo/dock_a11y"
	_input.tooltip_text = "Folder with *_dock.gd files to audit. Use res://addons to audit every dock."
	add_child(_input)
	var button := Button.new()
	button.text = "Audit docks"
	button.tooltip_text = "Check docks for tooltips, a run action and keyboard focus. Read-only."
	button.pressed.connect(_on_run)
	add_child(button)
	_output = RichTextLabel.new()
	_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_output.selection_enabled = true
	_output.tooltip_text = "Findings per dock with plain-words fixes. See the addon README and docs/DOCK_A11Y.md."
	_output.text = "Audit editor docks for accessibility."
	add_child(_output)

func _on_run() -> void:
	var result: Dictionary = Core.new().run(_input.text.strip_edges(), {})
	var lines: Array[String] = ["Summary: " + str(result["summary"])]
	for issue in result["issues"]:
		lines.append("[%s] %s - %s" % [issue["kind"], issue["message"], issue["fix"]])
	_output.text = "\n".join(lines)
