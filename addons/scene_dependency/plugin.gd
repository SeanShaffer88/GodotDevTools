@tool
extends EditorPlugin

const Dock := preload("res://addons/scene_dependency/ui/sdm_dock.gd")
var _dock: Control

func _enter_tree() -> void:
    _dock = Dock.new()
    add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)
    add_tool_menu_item("Scene Dependency Map: Run", func() -> void: _dock._on_run())

func _exit_tree() -> void:
    remove_tool_menu_item("Scene Dependency Map: Run")
    remove_control_from_docks(_dock)
    _dock.queue_free()
