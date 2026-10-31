## Physics Collision Matrix Visualizer - in-game contact counter.
## Attach as a child of an Area2D (or call watch() on any area) and it
## records every body/area contact with the layer bits involved, so the
## live matrix can be compared against the static one the core builds:
## pairs that never fire in real play are wasted mask bits, and pairs
## that fire constantly deserve a named layer of their own. Counts are
## plain data - get_counts() or save_json() feed them back into reports.
extends Node

signal counts_changed(bit: int, total: int)

const Matrix := preload("res://addons/collision_matrix/core/cmv_matrix.gd")

## Set false to pause recording without disconnecting signals.
@export var record_contacts: bool = true

## {layer_bit: contact_count} - bits are 0-based indices into the
## project's named physics layers.
var counts: Dictionary = {}

var _watched: Array = []


func _ready() -> void:
    var parent := get_parent()
    if parent is Area2D and parent not in _watched:
        watch(parent)


## Start counting contacts for one area.
func watch(area: Area2D) -> void:
    if area in _watched:
        return
    _watched.append(area)
    area.body_entered.connect(_on_contact.bind(area))
    area.area_entered.connect(_on_contact.bind(area))


func _on_contact(other: Node, area: Area2D) -> void:
    if not record_contacts:
        return
    var other_layers := 0
    if other is CollisionObject2D:
        other_layers = (other as CollisionObject2D).collision_layer
    elif other is CollisionObject3D:
        other_layers = (other as CollisionObject3D).collision_layer
    # The pair that actually fired: bits the area masks AND the other carries.
    var pair := area.collision_mask & other_layers
    var changed := false
    for bit in 32:
        if (pair >> bit) & 1:
            counts[bit] = int(counts.get(bit, 0)) + 1
            changed = true
    if changed:
        counts_changed.emit(pair, int(counts.size()))


## Total contacts recorded across all watched areas and bits.
func total_contacts() -> int:
    var total := 0
    for bit in counts:
        total += int(counts[bit])
    return total


func save_json(path: String = "user://collision_counts.json") -> bool:
    var f := FileAccess.open(path, FileAccess.WRITE)
    if f == null:
        return false
    f.store_string(JSON.stringify({"counts": counts, "total": total_contacts()}, "\t"))
    f.close()
    return true
