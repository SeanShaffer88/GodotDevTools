@tool
extends VBoxContainer
## Project Settings Drift Report dock. Thin shell over core/; results are read-only findings.
const Core := preload("res://addons/settings_drift/core/psd_drift.gd")
var _input: LineEdit
var _output: RichTextLabel

func _init() -> void:
    name = "Settings Drift"
    custom_minimum_size = Vector2(320, 260)
    var row := HBoxContainer.new()
    var label := Label.new()
    label.text = "Project file"
    label.tooltip_text = "The current project.godot (or copy) to compare."
    _input = LineEdit.new()
    _input.text = "res://project.godot"
    _input.tooltip_text = label.tooltip_text
    _input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(label)
    row.add_child(_input)
    add_child(row)
    var button := Button.new()
    button.text = "Compare with baseline"
    button.tooltip_text = "Diff project settings against the baseline file named on the command line (dock: res://project_baseline.godot). Read-only."
    button.pressed.connect(_on_run)
    add_child(button)
    _output = RichTextLabel.new()
    _output.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _output.selection_enabled = true
    _output.tooltip_text = "Summary, then each finding with its suggested fix. See the addon README for scope and limits."
    _output.text = "Compare project settings with a baseline. Create the baseline by copying project.godot when settings are approved."
    add_child(_output)

func _on_run() -> void:
    var result: Dictionary = Core.new().run(_input.text.strip_edges(), {})
    var lines: Array[String] = ["Summary: " + str(result["summary"])]
    for issue in result["issues"]:
        lines.append("[%s] %s:%s - %s Fix: %s" % [issue["kind"], issue.get("path", ""), issue.get("line", "-"), issue["message"], issue["fix"]])
    _output.text = "\n".join(lines)
