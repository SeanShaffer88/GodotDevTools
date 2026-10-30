## Game-State Time Machine - editor dock.
@tool
extends VBoxContainer

const Recorder := preload("res://addons/time_machine/core/gstm_recorder.gd")

var _results: RichTextLabel


func _init() -> void:
    name = "Game-State Time Machine"
    custom_minimum_size = Vector2(320, 200)
    var title := Label.new()
    title.text = "Game-State Time Machine"
    title.tooltip_text = "Record inputs and state snapshots so you can rewind a bug, inspect variables, and replay the exact sequence that caused it. Includes an in-game recorder node."
    add_child(title)
    var run_btn := Button.new()
    run_btn.text = "Run check"
    run_btn.tooltip_text = "Run the Game-State Time Machine check on this project and list the results below."
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


const HELP_TEXT := "In game: add the Time Machine node (addons/time_machine/runtime/gstm_node.gd), register state providers/restorers, and it records every physics frame. Save a session, then this dock (or the CLI) verifies the session file so it can be replayed exactly. rewind_to(frame) restores a snapshot; diff_states(a, b) shows which variables changed."


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
    var op = Recorder.new()
    return op.verify_session("res://time_machine_session.json")
