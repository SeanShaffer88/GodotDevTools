## Frame-Time Spike Investigator - runtime recorder.
## Add as an autoload or to a test scene. Records frame time, physics time
## and node count each frame from Performance monitors; call mark("label")
## around suspect work and save_log() to write the JSON the investigator
## reads. Keeps at most max_frames frames (ring buffer).
extends Node

@export var enabled: bool = true
@export var max_frames: int = 18000
@export var output_path: String = "user://frame_log.json"

var _frames: Array = []
var _pending: Array = []
var _count: int = 0


func mark(label: String) -> void:
    _pending.append(label)


func _process(delta: float) -> void:
    if not enabled:
        return
    record(delta * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))


## Append one frame (exposed for tests and custom loops).
func record(ms: float, physics_ms: float, nodes: int) -> void:
    _frames.append({"frame": _count, "ms": snappedf(ms, 0.001), "physics_ms": snappedf(physics_ms, 0.001), "nodes": nodes, "markers": _pending})
    _pending = []
    _count += 1
    if _frames.size() > max_frames:
        _frames.pop_front()


func log_data() -> Dictionary:
    return {"fps_target": Engine.max_fps if Engine.max_fps > 0 else 60, "frames": _frames}


func save_log(path: String = "") -> Error:
    var f := FileAccess.open(output_path if path == "" else path, FileAccess.WRITE)
    if f == null:
        return FileAccess.get_open_error()
    f.store_string(JSON.stringify(log_data()))
    return OK
