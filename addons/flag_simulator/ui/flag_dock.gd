@tool
extends VBoxContainer
const Simulator := preload("res://addons/flag_simulator/core/flag_simulator.gd")
var _config: LineEdit
var _subject: LineEdit
var _unavailable: CheckBox
var _output: RichTextLabel

func _init() -> void:
    name = "Flag Simulator"
    custom_minimum_size = Vector2(320, 250)
    _config = LineEdit.new()
    _config.text = "res://demo/flags/flags.json"
    _config.tooltip_text = "Flag configuration JSON path."
    add_child(_config)
    _subject = LineEdit.new()
    _subject.text = "demo-subject"
    _subject.tooltip_text = "Synthetic subject identifier for stable bucketing; do not use personal data."
    add_child(_subject)
    _unavailable = CheckBox.new()
    _unavailable.text = "Simulate unavailable configuration"
    _unavailable.tooltip_text = "Use local defaults instead of rollout percentages."
    add_child(_unavailable)
    var button := Button.new()
    button.text = "Simulate"
    button.tooltip_text = "Simulate flag decisions without connecting to a service."
    button.pressed.connect(_on_run)
    add_child(button)
    _output = RichTextLabel.new()
    _output.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _output.text = "Choose a configuration and synthetic subject, then simulate."
    add_child(_output)

func _on_run() -> void:
    var result: Dictionary = Simulator.new().run(_config.text, _subject.text, not _unavailable.button_pressed)
    _output.text = Simulator.new().to_markdown(result)
