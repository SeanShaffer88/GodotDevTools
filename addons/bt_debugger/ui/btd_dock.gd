## Behaviour Tree and State Machine Debugger - editor dock.
@tool
extends VBoxContainer

const Core := preload("res://addons/bt_debugger/core/btd_machine.gd")

var _results: RichTextLabel


func _init() -> void:
    name = "Behaviour Tree and State Machine Debugger"
    custom_minimum_size = Vector2(320, 200)
    var title := Label.new()
    title.text = "Behaviour Tree and State Machine Debugger"
    title.tooltip_text = "Validate and run JSON behaviour definitions with a full decision trace; live agents share the same interpreter."
    add_child(title)
    var run_btn := Button.new()
    run_btn.text = "Run check"
    run_btn.tooltip_text = "Run the Behaviour Tree and State Machine Debugger on this project and list the results below."
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


const HELP_TEXT := "Loads a JSON behaviour definition - states with selector and sequence trees, guarded transitions, blackboard conditions and actions - validates the graph (missing states, unreachable states, states that do nothing on entry) and then runs it, recording every decision as a trace. The dock shows the trace; the runtime agent node drives a real scene from the same definition, so what you debug is what ships."


func _json(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


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
    for key in ["trace", "plan", "specs", "remap_menu", "applied_steps"]:
        var extra: Array = result.get(key, [])
        var shown := 0
        for row in extra:
            if shown >= 40:
                lines.append("... %d more %s row(s)" % [extra.size() - 40, key])
                break
            lines.append("%s: %s" % [key, str(row)])
            shown += 1
    _results.text = "\n".join(lines)


func _run_check() -> Dictionary:
    var op = Core.new()
    var loaded := op.load_definition("res://demo/ai/guard_bt.json")
    var definition: Dictionary = loaded["definition"]
    var result: Dictionary = op.run(definition, definition.get("blackboard", {}))
    result["issues"] = (loaded["errors"] as Array) + (result.get("issues", []) as Array)
    result["summary"]["issues"] = (result["issues"] as Array).size()
    return result
