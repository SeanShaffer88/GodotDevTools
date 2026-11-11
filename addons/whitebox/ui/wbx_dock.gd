## Level Whiteboxing and Snapping Suite - editor dock.
@tool
extends VBoxContainer

const Core := preload("res://addons/whitebox/core/wbx_snap.gd")

var _results: RichTextLabel
var _grid_step: SpinBox
var _subdivisions: SpinBox
var _selection: EditorSelection
var _undo_redo: EditorUndoRedoManager


func configure_editor(selection: EditorSelection, undo_redo: EditorUndoRedoManager) -> void:
    _selection = selection
    _undo_redo = undo_redo


func _init() -> void:
    name = "Level Whiteboxing and Snapping Suite"
    custom_minimum_size = Vector2(320, 200)
    var title := Label.new()
    title.text = "Level Whiteboxing and Snapping Suite"
    title.tooltip_text = "Grid snapping and slope maths plus a scene scan for off-grid blockout props and unwalkable ramps."
    add_child(title)
    var run_btn := Button.new()
    run_btn.text = "Run check"
    run_btn.tooltip_text = "Audit the included whitebox example. Use the CLI --scene option to audit another scene."
    run_btn.pressed.connect(_on_run)
    add_child(run_btn)
    var help_btn := Button.new()
    help_btn.text = "?"
    help_btn.tooltip_text = "Show plain-words help for this tool."
    help_btn.pressed.connect(func() -> void: _results.text = HELP_TEXT)
    add_child(help_btn)
    var grid_row := HBoxContainer.new()
    var grid_label := Label.new()
    grid_label.text = "Grid size"
    grid_label.tooltip_text = "Local-space grid size for the selected 3D nodes."
    grid_row.add_child(grid_label)
    _grid_step = SpinBox.new()
    _grid_step.min_value = 0.01
    _grid_step.max_value = 10000.0
    _grid_step.step = 0.01
    _grid_step.value = 1.0
    _grid_step.tooltip_text = "Grid size in local units. The selected nodes' local positions are snapped."
    grid_row.add_child(_grid_step)
    var subdivisions_label := Label.new()
    subdivisions_label.text = "Divisions"
    subdivisions_label.tooltip_text = "Number of equal parts in one grid cell."
    grid_row.add_child(subdivisions_label)
    _subdivisions = SpinBox.new()
    _subdivisions.min_value = 1
    _subdivisions.max_value = 64
    _subdivisions.step = 1
    _subdivisions.value = 1
    _subdivisions.tooltip_text = "Divide a grid cell into this many parts before snapping."
    grid_row.add_child(_subdivisions)
    add_child(grid_row)
    var snap_btn := Button.new()
    snap_btn.text = "Snap selected 3D positions"
    snap_btn.tooltip_text = "Snap selected Node3D local positions to the grid as one undoable editor action. Other node types are skipped."
    snap_btn.pressed.connect(_on_snap_selection)
    add_child(snap_btn)
    _results = RichTextLabel.new()
    _results.fit_content = true
    _results.custom_minimum_size = Vector2(320, 300)
    _results.tooltip_text = "Results of the last run. Run the check to fill this in."
    add_child(_results)
    _results.text = "Press Run check."


const HELP_TEXT := "The blockout maths and its audit: snap positions to a grid (whole cells or subdivisions), snap rotations to a step, and judge slopes between walk points against your character controller's limit. The scene scan reads Node3D transforms from scene text and reports props floating between cells and ramps too steep to climb. Snap selected 3D positions changes local positions only, supports subdivisions, and is one undoable editor action. Rotations are not changed."


func _on_snap_selection() -> void:
    if _selection == null or _undo_redo == null:
        _results.text = "Open this dock in the editor to snap a selection."
        return
    var scene := EditorInterface.get_edited_scene_root()
    if scene == null:
        _results.text = "Open a scene and select one or more 3D nodes first."
        return
    var selected := _selection.get_selected_nodes()
    var changes: Array = []
    var skipped := 0
    var op = Core.new()
    for node in selected:
        if not (node is Node3D) or (node != scene and not scene.is_ancestor_of(node)):
            skipped += 1
            continue
        var spatial := node as Node3D
        var before := spatial.position
        var after: Vector3 = op.snap_position(before, _grid_step.value, int(_subdivisions.value))
        if not before.is_equal_approx(after):
            changes.append({"node": spatial, "before": before, "after": after})
    if changes.is_empty():
        _results.text = "No selected 3D positions need snapping (%d other node(s) skipped)." % skipped
        return
    _undo_redo.create_action("Snap selected 3D positions", UndoRedo.MERGE_DISABLE, scene)
    for change in changes:
        _undo_redo.add_do_property(change["node"], &"position", change["after"])
        _undo_redo.add_undo_property(change["node"], &"position", change["before"])
    _undo_redo.commit_action()
    _results.text = "Snapped %d local position(s); skipped %d other node(s). Use Undo to restore them." % [changes.size(), skipped]


func _json(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _on_run() -> void:
    var result: Dictionary = _run_check()
    var lines: Array[String] = []
    var s: Dictionary = result.get("summary", {})
    lines.append("Summary: " + str(s))
    var issues: Array = result.get("issues", [])
    if issues.is_empty():
        lines.append("No problems found.")
    for i in issues:
        lines.append("[%s] %s" % [i.get("severity", "info"), i.get("message", "")])
        if i.get("fix", "") != "":
            lines.append("  Fix: " + str(i["fix"]))
    for key in ["trace", "plan", "specs", "remap_menu", "applied_steps"]:
        var extra: Array = result.get(key, [])
        var shown := 0
        for row in extra:
            if shown >= 40:
                lines.append("... %d more %s row(s)" % [extra.size() - 40, key])
                break
            lines.append("%s: %s" % [key, str(row)])
            shown += 1
    _results.text = "\n".join(lines)


func _run_check() -> Dictionary:
    var op = Core.new()
    var scene_text := ""
    if FileAccess.file_exists("res://demo/whitebox/blockout.tscn"):
        scene_text = FileAccess.get_file_as_string("res://demo/whitebox/blockout.tscn")
    return op.run(op.parse_scene(scene_text), _json("res://demo/whitebox/grid.json"))
