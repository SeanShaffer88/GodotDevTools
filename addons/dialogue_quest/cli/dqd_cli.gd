## Dialogue and Quest Debugger - headless CLI.
##   godot --headless --path . --script res://addons/dialogue_quest/cli/dqd_cli.gd -- [--file=<json>] [--simulate=<dialogue>:<picks e.g. 0,1>] [--state=<json>] [--fail-on=issues]
extends SceneTree

const Graph := preload("res://addons/dialogue_quest/core/dqd_graph.gd")


func _init() -> void:
    var args := OS.get_cmdline_user_args()
    var op = Graph.new()
    var files: Array = []
    for arg in args:
        if arg.begins_with("--file="): files.append(arg.trim_prefix("--file="))
    if files.is_empty():
        files = op.find_files()
    var loaded: Dictionary = op.load_files(files)
    var result: Dictionary = op.analyse()
    result["issues"] = loaded["errors"] + result["issues"]
    for arg in args:
        if arg.begins_with("--simulate="):
            var spec := arg.trim_prefix("--simulate=")
            var parts := spec.split(":")
            var st: Dictionary = {}
            for a2 in args:
                if a2.begins_with("--state="):
                    var parsed = JSON.parse_string(a2.trim_prefix("--state="))
                    if typeof(parsed) == TYPE_DICTIONARY: st = parsed
            var picks: Array = []
            if parts.size() == 2:
                for p in parts[1].split(",", false): picks.append(int(p))
            var sim: Dictionary = op.simulate(parts[0], picks, st)
            print("DQD simulation of '", parts[0], "': visited ", sim["visited"], " stopped: ", sim["stopped"], " state: ", sim["state"])
    _emit(op, result, args, "res://reports/dialogue_quest", ["issues", "missing_target", "bad_start"])

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
        _write(out_dir.path_join("dialogue_quest.json"), op.to_json(result))
    if formats.has("md"):
        _write(out_dir.path_join("dialogue_quest.md"), op.to_markdown(result))
    print("DQD summary: ", result.get("summary", {}))
    for i in result.get("issues", []):
        print("DQD [", i.get("severity", "info"), "] ", i.get("message", ""))
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
