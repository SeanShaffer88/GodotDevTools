## Responsive UI Previewer - editor dock.
@tool
extends VBoxContainer

const Evaluator := preload("res://addons/responsive_ui/core/ruip_evaluator.gd")
const PREVIEW_SIZES := [
    {"name": "Desktop", "size": Vector2i(1280, 720)},
    {"name": "Small window", "size": Vector2i(800, 600)},
    {"name": "Phone portrait", "size": Vector2i(390, 844)},
]

var _results: RichTextLabel
var _scene_path: LineEdit
var _preview_row: HBoxContainer
var _preview_scroll: ScrollContainer
var _preview_status: Label
var _preview_views: Array[SubViewport] = []


func _init() -> void:
    name = "Responsive UI Previewer"
    custom_minimum_size = Vector2(320, 200)
    var title := Label.new()
    title.text = "Responsive UI Previewer"
    title.tooltip_text = "Estimate layout issues and preview a trusted UI scene at several viewport sizes."
    add_child(title)
    var run_btn := Button.new()
    run_btn.text = "Run check"
    run_btn.tooltip_text = "Run the Responsive UI Previewer check on this project and list the results below."
    run_btn.pressed.connect(_on_run)
    add_child(run_btn)
    var help_btn := Button.new()
    help_btn.text = "?"
    help_btn.tooltip_text = "Show plain-words help for this tool."
    help_btn.pressed.connect(func() -> void: _results.text = HELP_TEXT)
    add_child(help_btn)
    _scene_path = LineEdit.new()
    _scene_path.placeholder_text = "res://path/to/ui_scene.tscn"
    _scene_path.tooltip_text = "Path of a trusted Control or CanvasLayer scene to instantiate in the preview panes."
    add_child(_scene_path)
    var preview_btn := Button.new()
    preview_btn.text = "Preview scene"
    preview_btn.tooltip_text = "Instantiate the selected trusted UI scene at three viewport sizes. Tool scripts may run."
    preview_btn.pressed.connect(_on_preview)
    add_child(preview_btn)
    _preview_status = Label.new()
    _preview_status.text = "Choose a trusted UI scene to preview."
    _preview_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _preview_status.tooltip_text = "Preview status. These panes do not simulate device safe areas or project window stretch."
    add_child(_preview_status)
    _preview_scroll = ScrollContainer.new()
    _preview_scroll.custom_minimum_size = Vector2(300, 205)
    _preview_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    _preview_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    _preview_scroll.tooltip_text = "Side-by-side, non-interactive viewport previews; scroll horizontally to see all sizes."
    _preview_row = HBoxContainer.new()
    _preview_scroll.add_child(_preview_row)
    add_child(_preview_scroll)
    _results = RichTextLabel.new()
    _results.fit_content = true
    _results.custom_minimum_size = Vector2(320, 150)
    _results.tooltip_text = "Results of the last run. Run the check to fill this in."
    add_child(_results)
    _results.text = "Press Run check."


const HELP_TEXT := "Run check estimates saved scene rectangles against nine sizes and the project stretch settings. For visual previews, enter a trusted Control or CanvasLayer scene and press Preview scene. Three non-interactive viewports render separate scene instances; tool scripts may execute. The panes do not reproduce device safe areas, window stretch, runtime input, or all project state."


func _clear_previews() -> void:
    _preview_views.clear()
    for child in _preview_row.get_children():
        _preview_row.remove_child(child)
        child.queue_free()


func _on_preview() -> void:
    _clear_previews()
    var path := _scene_path.text.strip_edges()
    if not path.begins_with("res://") or not ResourceLoader.exists(path, "PackedScene"):
        _preview_status.text = "Enter an existing res:// UI scene path."
        return
    var packed := ResourceLoader.load(path, "PackedScene") as PackedScene
    if packed == null:
        _preview_status.text = "Could not load that scene."
        return
    # Check the first instance before adding anything to the tree. Scene
    # constructors and @tool scripts may still run, so this is explicit opt-in.
    var first := packed.instantiate()
    if first == null or not (first is Control or first is CanvasLayer):
        if first != null:
            first.free()
        _preview_status.text = "The scene root must be a Control or CanvasLayer."
        return
    for i in PREVIEW_SIZES.size():
        var target: Dictionary = PREVIEW_SIZES[i]
        var dimensions: Vector2i = target["size"]
        var panel := VBoxContainer.new()
        var label := Label.new()
        label.text = "%s %d×%d" % [target["name"], dimensions.x, dimensions.y]
        label.tooltip_text = "Rendered viewport size before scaling into the dock."
        panel.add_child(label)
        var texture := TextureRect.new()
        texture.custom_minimum_size = Vector2(180, 165)
        texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
        texture.tooltip_text = "Non-interactive preview; not a device safe-area or stretch simulation."
        panel.add_child(texture)
        _preview_row.add_child(panel)
        var viewport := SubViewport.new()
        viewport.size = dimensions
        viewport.disable_3d = true
        viewport.gui_disable_input = true
        viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
        texture.add_child(viewport)
        texture.texture = viewport.get_texture()
        var instance := first if i == 0 else packed.instantiate()
        viewport.add_child(instance)
        _preview_views.append(viewport)
    _preview_status.text = "Previewing three sizes. Safe areas and window stretch are not simulated."


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
    var results_list: Array = result.get("results", [])
    for r in results_list:
        lines.append("%s - %s" % [r.get("path", ""), "; ".join(r.get("reasons", []))])
    _results.text = "\n".join(lines)


func _run_check() -> Dictionary:
    var op = Evaluator.new()
    return op.evaluate_project()
