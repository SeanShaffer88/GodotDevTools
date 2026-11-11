@tool
extends VBoxContainer
## Fix Engine dock. Preview by default; the checkbox is the explicit opt-in.
const Core := preload("res://addons/fix_engine/core/fxe_engine.gd")
var _report: LineEdit
var _apply: CheckBox
var _output: RichTextLabel

func _init() -> void:
	name = "Fix Engine"
	custom_minimum_size = Vector2(320, 260)
	_report = LineEdit.new()
	_report.text = "res://demo/fix_engine/report.json"
	_report.tooltip_text = "Path to a tool report JSON (summary + issues). Preview only unless Apply is ticked."
	add_child(_report)
	_apply = CheckBox.new()
	_apply.text = "Apply fixes (backs up first)"
	_apply.tooltip_text = "Off by default. Tick only to rename files; a backup copy is written before each rename."
	add_child(_apply)
	var button := Button.new()
	button.text = "Preview fixes"
	button.tooltip_text = "List allowlisted safe fixes from the report. Nothing is changed unless Apply is ticked."
	button.pressed.connect(_on_run)
	add_child(button)
	_output = RichTextLabel.new()
	_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_output.selection_enabled = true
	_output.tooltip_text = "Proposed renames, then findings with no safe fix. See the addon README for the allowlist."
	_output.text = "Preview safe fixes from a tool report."
	add_child(_output)

func _on_run() -> void:
	var op = Core.new()
	var result: Dictionary = op.run(_report.text.strip_edges(), {})
	var lines: Array[String] = ["Summary: " + str(result["summary"]), "Preview: " + op.preview(result.get("fixes", []))]
	if _apply.button_pressed and not result.get("fixes", []).is_empty():
		var applied: Dictionary = op.apply_fixes(result["fixes"], "res://", "res://reports/fix_engine/backup")
		lines.append("Applied: " + str(applied["summary"]))
	_output.text = "\n".join(lines)
