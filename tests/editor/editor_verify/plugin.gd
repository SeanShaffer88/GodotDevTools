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
