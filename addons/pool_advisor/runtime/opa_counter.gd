## Object Pool Advisor - runtime spawn counter.
## Add as an autoload (or any node) in a play session. It counts nodes
## entering and leaving the tree by scene_file_path (instanced scenes
## only) and writes the counts file the advisor reads with --counts.
## Off by default in exported builds: it does nothing unless `enabled`.
extends Node

## Count only while true. Leave false in shipped builds.
@export var enabled: bool = true
## Where save_counts() writes when no path is given.
@export var output_path: String = "user://pool_counts.json"

var _counts: Dictionary = {}
var _started_ms: int = 0


func _enter_tree() -> void:
    _started_ms = Time.get_ticks_msec()
    get_tree().node_added.connect(_on_added)
    get_tree().node_removed.connect(_on_removed)


func _exit_tree() -> void:
    if get_tree().node_added.is_connected(_on_added):
        get_tree().node_added.disconnect(_on_added)
        get_tree().node_removed.disconnect(_on_removed)


func _on_added(node: Node) -> void:
    record(node.scene_file_path, "spawned")


func _on_removed(node: Node) -> void:
    record(node.scene_file_path, "freed")


## Count one event; exposed so tests and custom spawners can call it.
func record(scene_path: String, field: String) -> void:
    if not enabled or scene_path == "":
        return
    if field != "spawned" and field != "freed":
        push_warning("Pool counter: field must be \"spawned\" or \"freed\", got \"%s\"." % field)
        return
    if not _counts.has(scene_path):
        _counts[scene_path] = {"spawned": 0, "freed": 0}
    _counts[scene_path][field] += 1


## The counts dictionary in the format the advisor's --counts expects.
func snapshot(seconds: float = -1.0) -> Dictionary:
    if seconds <= 0.0:
        seconds = max(0.001, (Time.get_ticks_msec() - _started_ms) / 1000.0)
    return {"seconds": seconds, "scenes": _counts.duplicate(true)}


func save_counts(path: String = "") -> Error:
    var target := output_path if path == "" else path
    var file := FileAccess.open(target, FileAccess.WRITE)
    if file == null:
        return FileAccess.get_open_error()
    file.store_string(JSON.stringify(snapshot(), "  "))
    return OK


func reset() -> void:
    _counts.clear()
    _started_ms = Time.get_ticks_msec()
