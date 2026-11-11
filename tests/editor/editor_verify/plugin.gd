@tool
extends EditorPlugin
## Editor-session verification harness. Runs inside a real (windowed) Godot
## editor. For every GodotDevTools dock it brings the dock's tab to the front,
## clicks its run button with real mouse events through the editor viewport,
## waits for the output to change, saves a screenshot and records the result.
## Writes res://reports/editor_verify/editor_verify.json, then quits the editor.
## Test-only: tests/editor/run_editor_session.sh installs it into a scratch copy.

const OUT_DIR := "res://reports/editor_verify"
const SKIP_CLICK := {"macro_recorder": "needs a recorded macro and an open scene; checked separately below"}

var _results: Array = []


func _enter_tree() -> void:
	# Only a windowed editor counts as an editor session; the headless import
	# pass that precedes it must not drive the docks.
	if DisplayServer.get_name() != "headless":
		_run.call_deferred()


func _run() -> void:
	# The editor only redraws on change by default; screenshots need every frame drawn.
	OS.low_processor_usage_mode = false
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	for i in 30:
		await get_tree().process_frame
	var docks := _find_docks(EditorInterface.get_base_control())
	var addons: Array = []
	for a in DirAccess.get_directories_at("res://addons"):
		if FileAccess.file_exists("res://addons/%s/plugin.cfg" % a) and a != "editor_verify":
			addons.append(a)
	addons.sort()
	var only := OS.get_environment("GDT_VERIFY_ONLY")
	if only != "":
		addons = addons.filter(func(a): return a in only.split(","))
	for addon in addons:
		var row := {"addon": addon, "dock_in_editor": docks.has(addon), "clicked": false, "output_changed": false, "screenshot": ""}
		if docks.has(addon):
			var dock: Control = docks[addon]
			await _front(dock)
			row["visible"] = dock.is_visible_in_tree()
			if SKIP_CLICK.has(addon):
				row["note"] = SKIP_CLICK[addon]
				row.merge(await _macro_check(dock), true)
			else:
				var button := _run_button(dock)
				if button != null:
					var before := _text(dock)
					await _click(button)
					row["clicked"] = true
					for i in 20:
						await get_tree().process_frame
						if _text(dock) != before:
							break
					row["output_changed"] = _text(dock) != before and _text(dock).strip_edges() != ""
			var interaction: Dictionary = {}
			match addon:
				"visual_regression":
					interaction = await _capture_check(dock)
				"dialogue_quest":
					interaction = await _graph_check(dock)
				"responsive_ui":
					interaction = await _preview_check(dock)
				"whitebox":
					interaction = await _snap_check(dock)
			if not interaction.is_empty():
				row.merge(interaction, true)
				print("EDITOR_INTERACTION %s %s" % [addon, JSON.stringify(interaction)])
			row["screenshot"] = await _shot(addon)
		_results.append(row)
		print("EDITOR_VERIFY %s dock=%s clicked=%s changed=%s" % [addon, row["dock_in_editor"], row["clicked"], row["output_changed"]])
	var f := FileAccess.open(OUT_DIR.path_join("editor_verify.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"engine": Engine.get_version_info()["string"], "renderer": str(ProjectSettings.get_setting("rendering/renderer/rendering_method")),"video_adapter": RenderingServer.get_video_adapter_name(), "results": _results}, "  "))
	f.close()
	print("EDITOR_VERIFY_DONE %d" % _results.size())
	get_tree().quit()


## Map addon folder -> dock Control, found by the dock script's path.
func _find_docks(node: Node, out: Dictionary = {}) -> Dictionary:
	var s: Script = node.get_script()
	if s != null and s.resource_path.begins_with("res://addons/") and s.resource_path.contains("/ui/") and s.resource_path.ends_with("_dock.gd"):
		out[s.resource_path.split("/")[3]] = node
	for child in node.get_children():
		_find_docks(child, out)
	return out


func _front(dock: Control) -> void:
	var parent := dock.get_parent()
	if parent is TabContainer:
		(parent as TabContainer).current_tab = dock.get_index()
	for i in 3:
		await get_tree().process_frame


func _run_button(dock: Node) -> Button:
	for child in dock.get_children():
		if child is Button:
			for c in (child as Button).pressed.get_connections():
				if c["callable"].get_method() == "_on_run":
					return child
		var nested := _run_button(child)
		if nested != null:
			return nested
	return null


## A real click: mouse move, press and release at the button's centre, pushed
## through the editor window's viewport so focus, hover and theming apply.
func _click(button: Control) -> void:
	var vp := button.get_viewport()
	var pos := button.get_global_rect().get_center()
	var move := InputEventMouseMotion.new()
	move.position = pos
	move.global_position = pos
	vp.push_input(move)
	await get_tree().process_frame
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = pos
		ev.global_position = pos
		vp.push_input(ev)
		await get_tree().process_frame


func _macro_check(dock: Node) -> Dictionary:
	# Open a demo scene, then press Preview with a macro that edits it.
	var scene := "res://demo/workflow/drift/menu.tscn"
	var macro := "res://demo/macros/center_labels.json"
	EditorInterface.open_scene_from_path(scene)
	for i in 10:
		await get_tree().process_frame
	var out := {"opened_scene": EditorInterface.get_edited_scene_root() != null}
	for child in _all(dock):
		if child is LineEdit and str(child.text).ends_with(".json"):
			child.text = macro
	for child in _all(dock):
		if child is Button and child.text.to_lower().contains("preview"):
			var before := _text(dock)
			await _click(child)
			for i in 10:
				await get_tree().process_frame
			out["clicked"] = true
			out["output_changed"] = _text(dock) != before and not _text(dock).contains("Open a scene")
	# Record: start recording, select a Label in the edited scene, change its
	# text through the Inspector's own property editor (the path a user edit
	# takes), stop recording, and confirm the dock captured the step.
	var record: Button = null
	for child in _all(dock):
		if child is Button and child.text == "Start recording":
			record = child
	var label := EditorInterface.get_edited_scene_root().find_child("Label0", true, false) if EditorInterface.get_edited_scene_root() != null else null
	if record != null and label != null:
		await _click(record)
		EditorInterface.edit_node(label)
		for i in 10:
			await get_tree().process_frame
		var prop: EditorProperty = null
		for child in _all(EditorInterface.get_inspector()):
			if child is EditorProperty and (child as EditorProperty).get_edited_property() == &"text":
				prop = child
				break
		if prop != null:
			label.text = "Recorded by editor_verify"
			prop.emit_changed(&"text", label.text)
			for i in 5:
				await get_tree().process_frame
		await _click(record)
		out["recorded_steps"] = dock.get("_steps").size()
		out["record_captured"] = out["recorded_steps"] >= 1 and _text(dock).contains("Label0.text")
	return out


## The four checks below exercise the named controls and their results, not
## merely the generic run button or the presence of a screenshot.
func _capture_check(dock: Node) -> Dictionary:
	var out := {"capture_clicked": false, "capture_sizes": false, "capture_content": false, "capture_failures": []}
	var scenes: LineEdit = dock.get("_scenes_edit")
	var destination: LineEdit = dock.get("_out_edit")
	var button: Button = dock.get("_capture_btn")
	if scenes == null or destination == null or button == null:
		return out
	scenes.text = "res://tests/editor/fixtures/color_ui.tscn"
	destination.text = OUT_DIR.path_join("captures")
	await _click(button)
	out["capture_clicked"] = true
	for i in 1800:
		if not button.disabled:
			break
		await get_tree().process_frame
	var sizes: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(1152, 648), Vector2i(800, 600), Vector2i(390, 844)]
	var sizes_ok := not button.disabled
	var content_ok := sizes_ok
	for size in sizes:
		var path := destination.text.path_join("color_ui__%dx%d.png" % [size.x, size.y])
		var image := Image.new()
		if image.load(path) != OK or image.get_size() != size:
			sizes_ok = false
			content_ok = false
			out["capture_failures"].append(path + " missing or wrong size")
		elif not _fixture_pixels(image, size):
			content_ok = false
			out["capture_failures"].append(path + " did not contain the expected UI")
	out["capture_sizes"] = sizes_ok
	out["capture_content"] = content_ok
	return out


func _preview_check(dock: Node) -> Dictionary:
	var out := {"preview_clicked": false, "preview_sizes": false, "preview_content": false, "preview_failures": []}
	var edit: LineEdit = dock.get("_scene_path")
	var button := _button_named(dock, "Preview scene")
	if edit == null or button == null:
		return out
	edit.text = "res://tests/editor/fixtures/color_ui.tscn"
	await _click(button)
	out["preview_clicked"] = true
	for i in 6:
		await get_tree().process_frame
	var views: Array = dock.get("_preview_views")
	var scroll: ScrollContainer = dock.get("_preview_scroll")
	var sizes: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(800, 600), Vector2i(390, 844)]
	if views.size() != sizes.size() or scroll == null:
		out["preview_failures"].append("Expected three viewport panes")
		return out
	var sizes_ok := true
	var content_ok := true
	for i in views.size():
		var viewport: SubViewport = views[i]
		var panel: Control = viewport.get_parent().get_parent()
		scroll.ensure_control_visible(panel)
		for frame in 6:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		if viewport.size != sizes[i] or image == null or image.get_size() != sizes[i]:
			sizes_ok = false
			content_ok = false
			out["preview_failures"].append("Pane %d has the wrong size or no image" % i)
		elif not _fixture_pixels(image, sizes[i]):
			content_ok = false
			out["preview_failures"].append("Pane %d did not render the expected UI" % i)
	scroll.scroll_horizontal = 0
	out["preview_sizes"] = sizes_ok
	out["preview_content"] = content_ok
	return out


func _fixture_pixels(image: Image, size: Vector2i) -> bool:
	# The red backdrop fills the viewport and the green square is anchored to
	# the right edge. Both must really be rendered at each target size.
	if image == null or image.get_size() != size:
		return false
	var red := image.get_pixel(10, 10)
	var green := image.get_pixel(size.x - 80, 80)
	return red.r > 0.55 and red.r > red.g * 2.0 and green.g > 0.5 and green.g > green.r * 2.0


func _graph_check(dock: Node) -> Dictionary:
	var out := {"graph_layout": false, "graph_painted": false, "graph_evidence": ""}
	var view: Control = dock.get("_graph_view")
	if view == null or not view.is_visible_in_tree():
		out["graph_evidence"] = "Graph view is not visible"
		return out
	var layout: Dictionary = view.get("layout")
	var intro: Dictionary = {}
	var ghost := false
	var broken := false
	for node in layout.get("nodes", []):
		if node.get("id", "") == "intro":
			intro = node
		if node.get("id", "") == "ghost_node" and node.get("ghost", false):
			ghost = true
	for edge in layout.get("edges", []):
		if edge.get("from", "") == "intro" and edge.get("to", "") == "ghost_node" and edge.get("broken", false):
			broken = true
	out["graph_layout"] = not intro.is_empty() and ghost and broken
	if not out["graph_layout"]:
		out["graph_evidence"] = "Expected intro, missing target, and broken edge"
		return out
	await RenderingServer.frame_post_draw
	var image := EditorInterface.get_base_control().get_viewport().get_texture().get_image()
	var rect: Rect2 = intro["rect"]
	var origin := view.get_global_rect().position + rect.position
	var scroll: Control = view.get_parent()
	var colored := 0
	# The fixture's intro node has a missing target and is outlined orange.
	for x in range(12, int(rect.size.x) - 12):
		for y in range(-1, 3):
			var point := Vector2i(origin + Vector2(x, y))
			if image != null and point.x >= 0 and point.y >= 0 and point.x < image.get_width() and point.y < image.get_height() and scroll.get_global_rect().has_point(Vector2(point)):
				var pixel := image.get_pixelv(point)
				if pixel.r > 0.65 and pixel.g > 0.35 and pixel.b < 0.5:
					colored += 1
	out["graph_painted"] = colored >= 20
	out["graph_evidence"] = "orange outline pixels: %d" % colored
	return out


func _snap_check(dock: Node) -> Dictionary:
	var out := {"snap_clicked": false, "snap_applied": false, "snap_undo": false, "snap_redo": false, "snap_evidence": ""}
	EditorInterface.open_scene_from_path("res://demo/whitebox/blockout.tscn")
	for i in 15:
		await get_tree().process_frame
	var scene := EditorInterface.get_edited_scene_root()
	var crate: Node3D = null
	if scene != null:
		crate = scene.get_node_or_null("Crate") as Node3D
	var button := _button_named(dock, "Snap selected 3D positions")
	var grid: SpinBox = dock.get("_grid_step")
	var subdivisions: SpinBox = dock.get("_subdivisions")
	if crate == null or button == null or grid == null or subdivisions == null:
		out["snap_evidence"] = "Scene, crate or snap controls unavailable"
		return out
	var before := crate.position
	grid.value = 1.0
	subdivisions.value = 2
	var selected := EditorInterface.get_selection()
	selected.clear()
	selected.add_node(crate)
	await _click(button)
	out["snap_clicked"] = true
	out["snap_applied"] = before.is_equal_approx(Vector3(2.37, 0, 4)) and crate.position.is_equal_approx(Vector3(2.5, 0, 4))
	# A second no-op must not create an undo entry that obscures the snap.
	await _click(button)
	var manager := get_undo_redo()
	var history := manager.get_history_undo_redo(manager.get_object_history_id(crate))
	if history != null:
		out["snap_undo"] = history.undo() and crate.position.is_equal_approx(before)
		out["snap_redo"] = history.redo() and crate.position.is_equal_approx(Vector3(2.5, 0, 4))
	out["snap_evidence"] = "before=%s after=%s" % [str(before), str(crate.position)]
	return out


func _button_named(node: Node, text: String) -> Button:
	for child in _all(node):
		if child is Button and child.text == text:
			return child
	return null


func _all(node: Node) -> Array:
	var out: Array = [node]
	for c in node.get_children():
		out.append_array(_all(c))
	return out


func _shot(addon: String) -> String:
	await RenderingServer.frame_post_draw
	var img := EditorInterface.get_base_control().get_viewport().get_texture().get_image()
	if img == null:
		return ""
	var path := OUT_DIR.path_join("%s.png" % addon)
	img.save_png(path)
	return path


func _text(node: Node) -> String:
	var parts: PackedStringArray = []
	if node is RichTextLabel:
		parts.append((node as RichTextLabel).get_parsed_text())
	elif node is Label or node is TextEdit:
		parts.append(node.text)
	elif node is ItemList:
		parts.append(str((node as ItemList).item_count))
	elif node is Tree:
		var r := (node as Tree).get_root()
		parts.append(str(r.get_child_count() if r != null else -1))
	for child in node.get_children():
		parts.append(_text(child))
	return "\n".join(parts)
