## Dialogue and Quest Debugger - editor dock.
@tool
extends VBoxContainer

const Graph := preload("res://addons/dialogue_quest/core/dqd_graph.gd")

var _results: RichTextLabel


func _init() -> void:
    name = "Dialogue and Quest Debugger"
    custom_minimum_size = Vector2(320, 200)
    var title := Label.new()
    title.text = "Dialogue and Quest Debugger"
    title.tooltip_text = "Show dialogue branches and quest dependencies as a graph, simulate choices, and inspect which conditions activate."
    add_child(title)
    var run_btn := Button.new()
    run_btn.text = "Run check"
    run_btn.tooltip_text = "Run the Dialogue and Quest Debugger check on this project and list the results below."
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


const HELP_TEXT := "Dialogue/quest JSON files anywhere in the project are found automatically. Run lists branches pointing at missing nodes, unreachable writing, unmarked dead ends and quest dependency problems. The core's simulate(dialogue, picks, state) plays a conversation: it evaluates each choice's condition against the state you give it and applies effects, so you can see exactly which branches open."


func _on_run() -> void:
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
    var op = Graph.new()
    var found: Dictionary = {"errors": []}
    var files := op.find_files()
    found = op.load_files(files)
    var result := op.analyse()
    result["issues"] = found["errors"] + result["issues"]
    return result
