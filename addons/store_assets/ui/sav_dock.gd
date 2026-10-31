@tool
extends VBoxContainer
## Store Asset Validator dock. Thin shell over core/; results are read-only findings.
const Core := preload("res://addons/store_assets/core/sav_validator.gd")
var _input: LineEdit
var _output: RichTextLabel

func _init() -> void:
    name = "Store Assets"
    custom_minimum_size = Vector2(320, 260)
    var row := HBoxContainer.new()
    var label := Label.new()
    label.text = "Profile"
    label.tooltip_text = "JSON listing each store asset and its required size."
    _input = LineEdit.new()
    _input.text = "res://demo/shipping/store/profile.json"
    _input.tooltip_text = label.tooltip_text
    _input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(label)
    row.add_child(_input)
    add_child(row)
    var button := Button.new()
    button.text = "Validate store assets"
    button.tooltip_text = "Check every asset in the profile exists with an allowed size. Read-only."
    button.pressed.connect(_on_run)
    add_child(button)
    _output = RichTextLabel.new()
    _output.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _output.selection_enabled = true
    _output.tooltip_text = "Summary, then each finding with its suggested fix. See the addon README for scope and limits."
    _output.text = "Validate store assets against your profile. The profile is yours: copy sizes from each store's current documentation."
    add_child(_output)

func _on_run() -> void:
    var result: Dictionary = Core.new().run(_input.text.strip_edges(), {})
    var lines: Array[String] = ["Summary: " + str(result["summary"])]
    for issue in result["issues"]:
        lines.append("[%s] %s:%s - %s Fix: %s" % [issue["kind"], issue.get("path", ""), issue.get("line", "-"), issue["message"], issue["fix"]])
    _output.text = "\n".join(lines)
