@tool
extends VBoxContainer
## Suite Presets dock. Preview only; applying is done via the CLI with --apply.
const Core := preload("res://addons/suite_presets/core/spm_presets.gd")
var _preset: OptionButton
var _output: RichTextLabel

func _init() -> void:
	name = "Suite Presets"
	custom_minimum_size = Vector2(320, 260)
	_preset = OptionButton.new()
	_preset.tooltip_text = "Plugin profile to preview. Full enables everything; packs enable only their tools."
	for key in Core.PRESETS.keys():
		_preset.add_item(str(Core.PRESETS[key]["label"]), Core.PRESETS.keys().find(key))
	_preset.selected = 0
	add_child(_preset)
	var button := Button.new()
	button.text = "Preview preset"
	button.tooltip_text = "List which plugins the preset enables and disables. Read-only; use the CLI --apply to write project.godot."
	button.pressed.connect(_on_run)
	add_child(button)
	_output = RichTextLabel.new()
	_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_output.selection_enabled = true
	_output.tooltip_text = "Enabled and disabled plugin lists for the chosen preset. See the addon README."
	_output.text = "Preview a plugin preset."
	add_child(_output)

func _on_run() -> void:
	var key: String = str(Core.PRESETS.keys()[_preset.selected])
	var result: Dictionary = Core.new().run(key, {})
	var lines: Array[String] = ["Summary: " + str(result["summary"]), "Enabled: " + ", ".join(result.get("enabled", []).slice(0, 12))]
	_output.text = "\n".join(lines)
