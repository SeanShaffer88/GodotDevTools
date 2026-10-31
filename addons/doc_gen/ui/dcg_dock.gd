## Automated Documentation Generator for GDScript - editor dock.
@tool
extends VBoxContainer

const Core := preload("res://addons/doc_gen/core/dcg_parser.gd")

var _results: RichTextLabel


func _init() -> void:
    name = "Automated Documentation Generator for GDScript"
    custom_minimum_size = Vector2(320, 200)
    var title := Label.new()
    title.text = "Automated Documentation Generator for GDScript"
    title.tooltip_text = "Parse doc comments, signals, exports and functions into Markdown and HTML; report undocumented public API."
    add_child(title)
    var run_btn := Button.new()
    run_btn.text = "Run check"
    run_btn.tooltip_text = "Run the Automated Documentation Generator for GDScript on this project and list the results below."
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


const HELP_TEXT := "Parses GDScript source into API facts - the ## doc comment on each declaration, signals, exports, constants, functions with typed parameters, defaults and returns - and renders Markdown plus a dependency-free HTML page. Parsing is line-based and never executes the scripts, so it is safe on broken or half-written code. Public functions and exports with no doc comment are reported, because generated docs full of empty descriptions are just prettier no-docs."


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
    return op.run()
