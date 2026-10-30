## Game-State Time Machine - headless CLI.
##   godot --headless --path . --script res://addons/time_machine/cli/gstm_cli.gd -- --session=res://session.json
## Verifies a recorded session file (frame order, parse, input count).
## Exit 2 with --fail-on=errors when the session is broken.
extends SceneTree

const Recorder := preload("res://addons/time_machine/core/gstm_recorder.gd")


func _init() -> void:
    var args := OS.get_cmdline_user_args()
    var session := "res://time_machine_session.json"
    for arg in args:
        if arg.begins_with("--session="): session = arg.trim_prefix("--session=")
    var op = Recorder.new()
    var result: Dictionary = op.verify_session(session)
    _emit(_Adapter.new(), result, args, "res://reports/time_machine", ["errors"])


class _Adapter:
    func to_json(result: Dictionary) -> String:
        return JSON.stringify({"summary": result["summary"], "issues": result["issues"]}, "\t")
    func to_markdown(result: Dictionary) -> String:
        var lines: Array[String] = ["# Time Machine Session Report", "",
            "%d frames, %d inputs, %d problems." % [result["summary"]["frames"], result["summary"]["inputs"], (result["issues"] as Array).size()], ""]
        for i in result["issues"]:
            lines.append("- [%s] %s" % [i["severity"], i["message"]])
        return "\n".join(lines) + "\n"

func _write(path: String, content: String) -> bool:
    var f := FileAccess.open(path, FileAccess.WRITE)
    if f == null:
        printerr("Could not write ", path)
        return false
    f.store_string(content)
    f.close()
    return true


func _emit(op, result: Dictionary, args: Array, default_out: String, fail_kinds: Array) -> void:
    var out_dir := default_out
    var formats: Array[String] = ["json", "md"]
    for arg in args:
        if arg.begins_with("--out="):
            out_dir = arg.trim_prefix("--out=")
        elif arg.begins_with("--format="):
            formats.assign(arg.trim_prefix("--format=").split(","))
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
    if formats.has("json"):
        _write(out_dir.path_join("time_machine.json"), op.to_json(result))
    if formats.has("md"):
        _write(out_dir.path_join("time_machine.md"), op.to_markdown(result))
    print("GSTM summary: ", result.get("summary", {}))
    for i in result.get("issues", []):
        print("GSTM [", i.get("severity", "info"), "] ", i.get("message", ""))
    var failed := false
    var fail_on: Array[String] = []
    for arg in args:
        if arg.begins_with("--fail-on="):
            fail_on.assign(arg.trim_prefix("--fail-on=").split(","))
    for k in fail_kinds:
        if fail_on.has(k):
            for i in result.get("issues", []):
                if i.get("kind", "") == k:
                    failed = true
    if fail_on.has("errors"):
        for i in result.get("issues", []):
            if i.get("severity", "") == "error":
                failed = true
    if fail_on.has("issues") and not (result.get("issues", []) as Array).is_empty():
        failed = true
    quit(2 if failed else 0)
