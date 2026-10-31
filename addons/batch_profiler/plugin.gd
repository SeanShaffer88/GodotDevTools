## Draw Call and Batching Profiler - editor plugin entry point.
@tool
extends EditorPlugin

const Dock := preload("res://addons/batch_profiler/ui/dbp_dock.gd")

var _dock: Control


func _enter_tree() -> void:
    _dock = Dock.new()
    add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)
    add_tool_menu_item("Draw Call and Batching Profiler: Run", func() -> void: _dock._on_run())


func _exit_tree() -> void:
    remove_tool_menu_item("Draw Call and Batching Profiler: Run")
    if _dock != null:
        remove_control_from_docks(_dock)
        _dock.queue_free()
