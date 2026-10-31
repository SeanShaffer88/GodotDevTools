@tool
extends VBoxContainer
## Controller Glyph and Prompt Validator dock. Thin shell over core/; results are read-only findings.
const Core := preload("res://addons/controller_glyphs/core/cgp_validator.gd")
var _input: LineEdit
var _output: RichTextLabel

func _init() -> void:
    name = "Glyphs and Prompts"
    custom_minimum_size = Vector2(320, 260)
    var row := HBoxContainer.new()
    var label := Label.new()
    label.text = "Prompts folder"
    label.tooltip_text = "Folder scanned for prompt text (CSV, PO, scripts, scenes, JSON)."
    _input = LineEdit.new()
    _input.text = "res://demo/glyphs"
    _input.tooltip_text = label.tooltip_text
    _input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(label)
    row.add_child(_input)
    add_child(row)
    var button := Button.new()
    button.text = "Validate prompts"
    button.tooltip_text = "Check action tokens in prompts against actions, bindings and glyph folders. Read-only."
    button.pressed.connect(_on_run)
    add_child(button)
    _output = RichTextLabel.new()
    _output.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _output.selection_enabled = true
    _output.tooltip_text = "Summary, then each finding with its suggested fix. See the addon README for scope and limits."
    _output.text = "Validate controller prompts and glyphs."
    add_child(_output)

func _on_run() -> void:
    var result: Dictionary = Core.new().run(_input.text.strip_edges(), {})
    var lines: Array[String] = ["Summary: " + str(result["summary"])]
    for issue in result["issues"]:
        lines.append("[%s] %s:%s - %s Fix: %s" % [issue["kind"], issue.get("path", ""), issue.get("line", "-"), issue["message"], issue["fix"]])
    _output.text = "\n".join(lines)
