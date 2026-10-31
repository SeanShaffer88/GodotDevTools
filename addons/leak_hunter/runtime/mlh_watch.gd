## Memory Leak and Orphan Node Hunter - in-game orphan watcher.
## The runtime half of the hunter, and an honest one: GDScript cannot
## enumerate objects that should have died, so this node watches the
## ones you hand it. Call detach(node) instead of remove_child(node):
## the node leaves the tree, the watcher keeps a weak reference, and
## after check_delay frames anything still alive is an orphan - out of
## the tree, still in RAM, reported with orphan_suspect. report() gives
## the counts; the static core scan finds the code patterns that make
## orphans, this node proves which ones actually leak in a session.
extends Node

signal orphan_suspect(node_name: String, detached_frames_ago: int)

## Frames a detached node gets to die before it is called a suspect.
@export var check_delay: int = 120
## How often (in frames) the watcher sweeps its tracked list.
@export var sweep_interval: int = 30

var _tracked: Array = []
var _freed := 0
var _suspects := 0
var _frame := 0


func _process(_delta: float) -> void:
    _frame += 1
    if _frame % maxi(sweep_interval, 1) != 0:
        return
    _sweep()


## Remove a node from the tree and track whether it ever gets freed.
func detach(node: Node) -> void:
    var parent := node.get_parent()
    if parent != null:
        parent.remove_child(node)
    track(node)


## Track a node that is already out of the tree.
func track(node: Node) -> void:
    _tracked.append({"ref": weakref(node), "name": str(node.name),
        "frame": _frame, "reported": false})


func _sweep() -> void:
    for i in range(_tracked.size() - 1, -1, -1):
        var entry: Dictionary = _tracked[i]
        var alive = (entry["ref"] as WeakRef).get_ref()
        if alive == null:
            _freed += 1
            _tracked.remove_at(i)
            continue
        if not bool(entry["reported"]) and _frame - int(entry["frame"]) >= check_delay:
            entry["reported"] = true
            _suspects += 1
            orphan_suspect.emit(str(entry["name"]), _frame - int(entry["frame"]))


## Session counts: detached, freed properly, and suspects still alive.
func report() -> Dictionary:
    return {"tracked": _tracked.size(), "freed": _freed, "suspects": _suspects,
        "suspect_names": _suspect_names()}


func _suspect_names() -> Array:
    var out: Array = []
    for entry in _tracked:
        if bool(entry["reported"]):
            out.append(entry["name"])
    return out
