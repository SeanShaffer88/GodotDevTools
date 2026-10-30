## Multiplayer Network Simulator - headless CLI.
##   godot --headless --path . --script res://addons/network_sim/cli/mns_cli.gd -- [--latency=<ticks>] [--jitter=<ticks>] [--loss=<0..1>] [--disconnect=<from>-<to>] [--ticks=<n>] [--fail-on=issues]
extends SceneTree

const Channel := preload("res://addons/network_sim/core/mns_channel.gd")


func _init() -> void:
    var args := OS.get_cmdline_user_args()
    var op = Channel.new()
    var ticks := 180
    for arg in args:
        if arg.begins_with("--latency="): op.latency_ticks = int(arg.trim_prefix("--latency="))
        elif arg.begins_with("--jitter="): op.jitter_ticks = int(arg.trim_prefix("--jitter="))
        elif arg.begins_with("--loss="): op.loss_fraction = float(arg.trim_prefix("--loss="))
        elif arg.begins_with("--ticks="): ticks = int(arg.trim_prefix("--ticks="))
        elif arg.begins_with("--disconnect="):
            var parts := arg.trim_prefix("--disconnect=").split("-")
            if parts.size() == 2: op.disconnect_windows.append(Vector2i(int(parts[0]), int(parts[1])))
    var result: Dictionary = op.run_sync_scenario(ticks)
    _emit(op, result, args, "res://reports/network_sim", ["issues", "packet_loss"])

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
        _write(out_dir.path_join("network_sim.json"), op.to_json(result))
    if formats.has("md"):
        _write(out_dir.path_join("network_sim.md"), op.to_markdown(result))
    print("MNS summary: ", result.get("summary", {}))
    for i in result.get("issues", []):
        print("MNS [", i.get("severity", "info"), "] ", i.get("message", ""))
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
