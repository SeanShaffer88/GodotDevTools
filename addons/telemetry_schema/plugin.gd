@tool
extends EditorPlugin
const Dock := preload("res://addons/telemetry_schema/ui/tel_dock.gd")
var _dock: Control

func _enter_tree() -> void:
    _dock = Dock.new()
    add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)

func _exit_tree() -> void:
    remove_control_from_docks(_dock)
    _dock.queue_free()
