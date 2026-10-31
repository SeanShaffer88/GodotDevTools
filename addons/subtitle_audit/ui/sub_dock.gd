@tool
extends VBoxContainer
const Audit := preload("res://addons/subtitle_audit/core/sub_audit.gd")
var _path: LineEdit
var _speaker: CheckBox
var _output: RichTextLabel

func _init() -> void:
    name = "Subtitle Audit"
    custom_minimum_size = Vector2(320, 250)
    _path = LineEdit.new()
    _path.text = "res://demo/subtitles/cues.json"
    _path.tooltip_text = "Path to subtitle JSON, SRT or WebVTT. See the addon README for supported formats."
    add_child(_path)
    _speaker = CheckBox.new()
    _speaker.text = "Require speaker labels"
    _speaker.tooltip_text = "Flag cues without a speaker label."
    add_child(_speaker)
    var button := Button.new()
    button.text = "Audit subtitles"
    button.tooltip_text = "Check cue timing and readability without changing the file."
    button.pressed.connect(_on_run)
    add_child(button)
    _output = RichTextLabel.new()
    _output.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _output.text = "Enter a subtitle JSON, SRT or VTT path, then audit."
    add_child(_output)

func _on_run() -> void:
    var result: Dictionary = Audit.new().run(_path.text, {"require_speaker": _speaker.button_pressed})
    var lines: Array[String] = ["Summary: " + str(result["summary"])]
    for issue in result["issues"]:
        lines.append("[%s] %s — %s" % [issue["kind"], issue["path"], issue["message"]])
    _output.text = "\n".join(lines)
