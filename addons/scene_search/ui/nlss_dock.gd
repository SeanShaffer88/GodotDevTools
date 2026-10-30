## Natural-Language Scene Search - editor dock.
@tool
extends VBoxContainer

const Search := preload("res://addons/scene_search/core/nlss_search.gd")

var _results: RichTextLabel
var _query_edit: LineEdit
var _query: String = "find enemies that use a patrol state"


func _init() -> void:
    name = "Natural-Language Scene Search"
    custom_minimum_size = Vector2(320, 200)
    var title := Label.new()
    title.text = "Natural-Language Scene Search"
    title.tooltip_text = "Search project content with queries like 'find enemies that use a patrol state' or 'show scenes with a door interaction', using project metadata and code indexing."
    add_child(title)
    _query_edit = LineEdit.new()
    _query_edit.placeholder_text = "find enemies that use a patrol state"
    _query_edit.tooltip_text = "Type a plain-words search, then Run check."
    add_child(_query_edit)
    var run_btn := Button.new()
    run_btn.text = "Run check"
    run_btn.tooltip_text = "Run the Natural-Language Scene Search check on this project and list the results below."
    run_btn.pressed.connect(_on_run)
    add_child(run_btn)
    var help_btn := Button.new()
    help_btn.text = "?"
    help_btn.tooltip_text = "Show plain-words help for this tool."
    help_btn.pressed.connect(func() -> void: _results.text = HELP_TEXT)
    add_child(help_btn)
    _results = RichTextLabel.new()
    _results.fit_content = true
    _results.custom_minimum_size = Vector2(320, 300)
    _results.tooltip_text = "Results of the last run. Run the check to fill this in."
    add_child(_results)
    _results.text = "Press Run check."


const HELP_TEXT := "Type a plain-words query (for example: find enemies that use a patrol state) and Run. The index covers scene node names and types, script functions, variables, class names and file names. Every result says why it matched, so the ranking can be checked. Matching is rule-based and offline - it matches the words in your project, not synonyms."


func _on_run() -> void:
    if _query_edit.text.strip_edges() != "":
        _query = _query_edit.text.strip_edges()
    var result: Dictionary = _run_check()
    var lines: Array[String] = []
    var s: Dictionary = result.get("summary", {})
    lines.append("Summary: " + str(s))
    var issues: Array = result.get("issues", [])
    if issues.is_empty():
        lines.append("No problems found.")
    for i in issues:
        lines.append("[%s] %s" % [i.get("severity", "info"), i.get("message", "")])
        if i.get("fix", "") != "":
            lines.append("  Fix: " + str(i["fix"]))
    var results_list: Array = result.get("results", [])
    for r in results_list:
        lines.append("%s - %s" % [r.get("path", ""), "; ".join(r.get("reasons", []))])
    _results.text = "\n".join(lines)


func _run_check() -> Dictionary:
    var op = Search.new()
    return op.search(_query)
