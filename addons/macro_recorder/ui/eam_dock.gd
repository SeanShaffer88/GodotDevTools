@tool
extends VBoxContainer
## Editor Action Macro Recorder dock. Record: every property edited in the
## Inspector on a node of the edited scene is captured as a macro step.
## Save writes the macro JSON; Preview shows what replaying a macro on the
## edited scene would change (no changes are made from the dock).
const Core := preload("res://addons/macro_recorder/core/eam_macro.gd")
var _core = Core.new()
var _recording := false
var _steps: Array = []
var _status: RichTextLabel
var _record: Button
var _path: LineEdit

func _init() -> void:
    name = "Macros"
    custom_minimum_size = Vector2(320, 260)
    _record = Button.new()
    _record.text = "Start recording"
    _record.tooltip_text = "Capture Inspector property edits on nodes of the edited scene as macro steps."
    _record.pressed.connect(_toggle)
    add_child(_record)
    _path = LineEdit.new()
    _path.text = "res://macros/new_macro.json"
    _path.tooltip_text = "Where Save writes the macro, and which macro Preview reads."
    add_child(_path)
    var row := HBoxContainer.new()
    var save := Button.new()
    save.text = "Save"
    save.tooltip_text = "Write the recorded steps to the macro path."
    save.pressed.connect(_save)
    var preview := Button.new()
    preview.text = "Preview on scene"
    preview.tooltip_text = "Show what the macro at the path would change in the edited scene. Nothing is modified."
    preview.pressed.connect(_preview)
    row.add_child(save)
    row.add_child(preview)
    add_child(row)
    _status = RichTextLabel.new()
    _status.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _status.selection_enabled = true
    _status.text = "Record Inspector edits as a macro, then preview or apply it to other scenes (apply from the command line)."
    add_child(_status)

func _toggle() -> void:
    _recording = not _recording
    _record.text = "Stop recording" if _recording else "Start recording"
    var inspector := EditorInterface.get_inspector()
    if _recording and not inspector.property_edited.is_connected(_on_edited):
        inspector.property_edited.connect(_on_edited)
    elif not _recording and inspector.property_edited.is_connected(_on_edited):
        inspector.property_edited.disconnect(_on_edited)

func _on_edited(property: String) -> void:
    var obj := EditorInterface.get_inspector().get_edited_object()
    var root := EditorInterface.get_edited_scene_root()
    if obj is Node and root != null and (obj == root or root.is_ancestor_of(obj)):
        var step := {"node": str(root.get_path_to(obj)), "property": property, "value": obj.get(property)}
        _steps.append(_core.to_json_step(step))
        _status.text = "%d step(s) recorded. Last: %s.%s" % [_steps.size(), step["node"], property]

func _save() -> void:
    var f := FileAccess.open(_path.text, FileAccess.WRITE)
    if f == null:
        _status.text = "Cannot write " + _path.text
        return
    f.store_string(JSON.stringify({"name": _path.text.get_file().get_basename(), "steps": _steps}, "  "))
    _status.text = "Saved %d step(s) to %s." % [_steps.size(), _path.text]

func _preview() -> void:
    var root := EditorInterface.get_edited_scene_root()
    var macro: Variant = JSON.parse_string(FileAccess.get_file_as_string(_path.text)) if FileAccess.file_exists(_path.text) else null
    if root == null or typeof(macro) != TYPE_DICTIONARY:
        _status.text = "Open a scene and point the path at a macro JSON."
        return
    var changes: Array = _core.plan(root, macro)
    _status.text = "\n".join(changes.map(func(c): return "%s.%s: %s -> %s" % [c["node"], c["property"], c["old"], c["new"]] if c.get("matched", true) else "Unmatched step: %s" % c["step"]))
