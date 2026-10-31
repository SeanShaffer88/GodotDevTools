## Record review metadata to a new queue file; does not modify baselines.
extends SceneTree
const Review := preload("res://addons/visual_regression/core/vrt_review.gd")

func _init() -> void:
    var queue_path := ""
    var output_path := ""
    var name := ""
    var decision := ""
    var reviewer := ""
    var note := ""
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--queue="): queue_path = arg.trim_prefix("--queue=")
        elif arg.begins_with("--out="): output_path = arg.trim_prefix("--out=")
        elif arg.begins_with("--name="): name = arg.trim_prefix("--name=")
        elif arg.begins_with("--decision="): decision = arg.trim_prefix("--decision=")
        elif arg.begins_with("--reviewer="): reviewer = arg.trim_prefix("--reviewer=")
        elif arg.begins_with("--note="): note = arg.trim_prefix("--note=")
    if queue_path.is_empty() or output_path.get_extension().to_lower() != "json" or ProjectSettings.globalize_path(queue_path).simplify_path() == ProjectSettings.globalize_path(output_path).simplify_path():
        printerr("Provide --queue and a distinct --out JSON path.")
        quit(1)
        return
    var input := FileAccess.open(queue_path, FileAccess.READ)
    if input == null:
        printerr("Cannot read queue.")
        quit(1)
        return
    var parser := JSON.new()
    if parser.parse(input.get_as_text()) != OK or typeof(parser.data) != TYPE_DICTIONARY:
        printerr("Invalid queue JSON.")
        quit(1)
        return
    var verdict: Dictionary = Review.new().decide(parser.data, name, decision, reviewer, note, Time.get_datetime_string_from_system(true))
    if not verdict["ok"]:
        printerr(verdict["error"])
        quit(2)
        return
    var output := FileAccess.open(output_path, FileAccess.WRITE)
    if output == null:
        printerr("Cannot write output queue.")
        quit(1)
        return
    output.store_string(JSON.stringify(verdict["queue"], "  "))
    output.flush()
    if output.get_error() != OK:
        printerr("Could not finish writing queue.")
        quit(1)
        return
    print("Recorded review metadata; baseline files were not changed.")
    quit(0)
