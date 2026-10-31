## Smart Prefab and Variant Instance Manager - editor plugin entry point.
@tool
extends EditorPlugin

const Dock := preload("res://addons/prefab_guard/ui/pfg_dock.gd")

var _dock: Control


func _enter_tree() -> void:
    _dock = Dock.new()
    add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)
    add_tool_menu_item("Smart Prefab and Variant Instance Manager: Run", func() -> void: _dock._on_run())


func _exit_tree() -> void:
    remove_tool_menu_item("Smart Prefab and Variant Instance Manager: Run")
    if _dock != null:
        remove_control_from_docks(_dock)
        _dock.queue_free()
