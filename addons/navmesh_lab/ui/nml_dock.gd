@tool
extends VBoxContainer
## Navigation Mesh Diagnostic Lab dock. Thin shell over core/; results are read-only findings.
const Core := preload("res://addons/navmesh_lab/core/nml_lab.gd")
var _input: LineEdit
var _output: RichTextLabel

func _init() -> void:
    name = "Navmesh Lab"
    custom_minimum_size = Vector2(320, 260)
    var row := HBoxContainer.new()
    var label := Label.new()
    label.text = "Navmesh"
    label.tooltip_text = "A .tres (or scene) holding a baked NavigationPolygon."
    _input = LineEdit.new()
    _input.text = "res://demo/gameplay/nav.tres"
    _input.tooltip_text = label.tooltip_text
    _input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(label)
    row.add_child(_input)
    add_child(row)
    var button := Button.new()
    button.text = "Diagnose navmesh"
    button.tooltip_text = "Check connectivity, passage widths and target reachability. Read-only."
    button.pressed.connect(_on_run)
    add_child(button)
    _output = RichTextLabel.new()
    _output.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _output.selection_enabled = true
    _output.tooltip_text = "Summary, then each finding with its suggested fix. See the addon README for scope and limits."
    _output.text = "Diagnose a baked 2D navigation polygon."
    add_child(_output)

func _on_run() -> void:
    var result: Dictionary = Core.new().run(_input.text.strip_edges(), {})
    var lines: Array[String] = ["Summary: " + str(result["summary"])]
    for issue in result["issues"]:
        lines.append("[%s] %s:%s - %s Fix: %s" % [issue["kind"], issue.get("path", ""), issue.get("line", "-"), issue["message"], issue["fix"]])
    _output.text = "\n".join(lines)
