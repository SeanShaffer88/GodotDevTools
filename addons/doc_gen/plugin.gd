## Automated Documentation Generator for GDScript - editor plugin entry point.
@tool
extends EditorPlugin

const Dock := preload("res://addons/doc_gen/ui/dcg_dock.gd")

var _dock: Control


func _enter_tree() -> void:
    _dock = Dock.new()
    add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)
    add_tool_menu_item("Automated Documentation Generator for GDScript: Run", func() -> void: _dock._on_run())


func _exit_tree() -> void:
    remove_tool_menu_item("Automated Documentation Generator for GDScript: Run")
    if _dock != null:
        remove_control_from_docks(_dock)
        _dock.queue_free()
