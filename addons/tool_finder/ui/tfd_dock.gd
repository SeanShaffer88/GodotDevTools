@tool
extends VBoxContainer
## Tool Finder dock. Thin shell over core/; search is read-only.
const Core := preload("res://addons/tool_finder/core/tfd_finder.gd")
var _query: LineEdit
var _output: RichTextLabel

func _init() -> void:
	name = "Tool Finder"
	custom_minimum_size = Vector2(320, 260)
	_query = LineEdit.new()
	_query.text = "my game lags on mobile"
	_query.tooltip_text = "Describe your problem in plain words, e.g. 'my game lags on mobile' or 'crash on load'."
	add_child(_query)
	var button := Button.new()
	button.text = "Find tools"
	button.tooltip_text = "Search the catalog by problem and list the best matches with reasons. Read-only."
	button.pressed.connect(_on_run)
	add_child(button)
	_output = RichTextLabel.new()
	_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_output.selection_enabled = true
	_output.tooltip_text = "Ranked matches with why each tool fits. See the addon README for the problem phrases."
	_output.text = "Describe a problem, then find tools."
	add_child(_output)

func _on_run() -> void:
	var result: Dictionary = Core.new().run(_query.text.strip_edges(), {})
	var lines: Array[String] = ["Summary: " + str(result["summary"])]
	for r in result.get("results", []):
		lines.append("%s (%s) - %s" % [r["title"], r["folder"], ", ".join(r["why"])])
	for issue in result["issues"]:
		lines.append("[%s] %s - %s" % [issue["kind"], issue["message"], issue["fix"]])
	_output.text = "\n".join(lines)
