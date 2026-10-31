@tool
extends VBoxContainer
const Validator := preload("res://addons/telemetry_schema/core/tel_validator.gd")
var _schema: LineEdit
var _samples: LineEdit
var _output: RichTextLabel

func _init() -> void:
    name = "Telemetry Schema"
    custom_minimum_size = Vector2(320, 250)
    _schema = LineEdit.new()
    _schema.text = "res://demo/telemetry/schema.json"
    _schema.tooltip_text = "Path to a local JSON schema; see addon README."
    add_child(_schema)
    _samples = LineEdit.new()
    _samples.text = "res://demo/telemetry/events.json"
    _samples.tooltip_text = "Path to local event samples. Avoid using real player data."
    add_child(_samples)
    var button := Button.new()
    button.text = "Validate samples"
    button.tooltip_text = "Validate locally without sending data or changing input files."
    button.pressed.connect(_on_run)
    add_child(button)
    _output = RichTextLabel.new()
    _output.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _output.text = "Enter schema and sample paths, then validate."
    add_child(_output)

func _on_run() -> void:
    var result: Dictionary = Validator.new().run(_schema.text, _samples.text)
    var lines: Array[String] = ["Summary: " + str(result["summary"])]
    for issue in result["issues"]:
        lines.append("[%s] %s — %s" % [issue["kind"], issue["path"], issue["message"]])
    _output.text = "\n".join(lines)
