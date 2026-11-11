@tool
extends VBoxContainer
## Offline logcat viewer; all parsing and grouping live in core/.
const Core := preload("res://addons/android_logcat_triage/core/alt_triage.gd")
var _input: LineEdit
var _package: LineEdit
var _output: RichTextLabel


func _init() -> void:
    name = "Android Logcat Triage"
    custom_minimum_size = Vector2(320, 260)
    _input = _field("Log file", "user://android_logcat.txt", "UTF-8 log saved with adb logcat -v threadtime. The original file is not modified.")
    _package = _field("Package", "", "Optional exact application ID; matching :remote processes are included. Unattributed crashes are excluded and counted.")
    var button := Button.new()
    button.text = "Triage logcat"
    button.tooltip_text = "Group supported Java fatal exceptions, libc fatal signals and ActivityManager ANRs."
    button.pressed.connect(_on_run)
    add_child(button)
    _output = RichTextLabel.new()
    _output.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _output.selection_enabled = true
    _output.tooltip_text = "Crash groups and hints omit raw messages, but names and paths may still be sensitive; review before sharing."
    _output.text = "Select a threadtime logcat file, then triage it."
    add_child(_output)


func _field(label_text: String, initial: String, tip: String) -> LineEdit:
    var row := HBoxContainer.new()
    var label := Label.new()
    label.text = label_text
    var edit := LineEdit.new()
    edit.text = initial
    edit.tooltip_text = tip
    edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(label)
    row.add_child(edit)
    add_child(row)
    return edit


func _on_run() -> void:
    var result: Dictionary = Core.new().run(_input.text.strip_edges(), {"package": _package.text.strip_edges()})
    var lines: Array[String] = ["Summary: " + str(result["summary"])]
    for group in result.get("groups", []):
        lines.append("%s × %s: %s" % [group["type"], group["count"], group["signature"]])
    for issue in result["issues"]:
        lines.append("[%s] line %s: %s Fix: %s" % [issue["kind"], issue["line"], issue["message"], issue["fix"]])
    _output.text = "\n".join(lines)
