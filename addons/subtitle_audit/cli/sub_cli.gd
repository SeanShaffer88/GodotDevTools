extends SceneTree
const Audit := preload("res://addons/subtitle_audit/core/sub_audit.gd")

func _init() -> void:
    var path := "res://demo/subtitles/cues.json"
    var out := "res://reports/subtitle_audit"
    var fail_on: Array = []
    var options := {}
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--input="):
            path = arg.trim_prefix("--input=")
        elif arg.begins_with("--out="):
            out = arg.trim_prefix("--out=")
        elif arg.begins_with("--fail-on="):
            fail_on = Array(arg.trim_prefix("--fail-on=").split(","))
        elif arg == "--require-speaker":
            options["require_speaker"] = true
    var op = Audit.new()
    var result: Dictionary = op.run(path, options)
    if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out)) != OK:
        printerr("Cannot create report directory: ", out)
        quit(1)
        return
    for pair in [["subtitle_audit.json", op.to_json(result)], ["subtitle_audit.md", op.to_markdown(result)]]:
        var file := FileAccess.open(out.path_join(pair[0]), FileAccess.WRITE)
        if file == null:
            printerr("Cannot write report: ", out.path_join(pair[0]))
            quit(1)
            return
        file.store_string(pair[1])
    print("Subtitle audit: ", result["summary"])
    var failed := false
    for issue in result["issues"]:
        print("[%s] %s: %s" % [issue["kind"], issue["path"], issue["message"]])
        if issue["severity"] == "error":
            quit(1)
            return
        if issue["kind"] in fail_on or "issues" in fail_on:
            failed = true
    quit(2 if failed else 0)
