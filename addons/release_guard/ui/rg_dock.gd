@tool
extends VBoxContainer
const Core := preload("res://addons/release_guard/core/rg_scanner.gd")
var _output: RichTextLabel

func _init() -> void:
    name = "Release Content Guard"
    custom_minimum_size = Vector2(320, 250)
    var button := Button.new()
    button.text = "Scan development markers"
    button.tooltip_text = "Review explicit markers in supported project text files. This does not inspect exported packages."
    button.pressed.connect(_on_run)
    add_child(button)
    _output = RichTextLabel.new()
    _output.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _output.tooltip_text = "Findings are candidates; manually review release inclusion."
    _output.text = "Scan the project for release-guard markers. See the addon README for scope."
    add_child(_output)

func _on_run() -> void:
    var result: Dictionary = Core.new().run()
    var lines: Array[String] = ["Summary: " + str(result["summary"])]
    for issue in result["issues"]:
        lines.append("[%s] %s:%s — %s" % [issue["kind"], issue["path"], issue.get("line", "-"), issue["message"]])
    _output.text = "\n".join(lines)
