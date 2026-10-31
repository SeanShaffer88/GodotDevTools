## Fixture: a RefCounted that connects to a longer-lived emitter's
## signal - the signal_hold suspect the leak hunter reports.
extends RefCounted

var _emitter: Node


## Hook onto whatever node hands itself over. The connection keeps this
## object referenced by the emitter for as long as the emitter lives.
func attach(emitter: Node) -> void:
    _emitter = emitter
    emitter.tree_exiting.connect(_on_tree_exiting)


func _on_tree_exiting() -> void:
    print("emitter leaving tree: ", _emitter.name)
