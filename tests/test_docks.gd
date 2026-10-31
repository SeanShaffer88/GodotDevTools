extends SceneTree
## Dock smoke test: instantiates every addon's editor dock outside the editor,
## checks that every interactive control has a tooltip, then presses the dock's
## run action against its default demo input and checks the output changed.
## Docks that need the running editor (EditorInterface) are only constructed;
## their editor-only actions are reported as skipped, not passed.

const EDITOR_ONLY_ACTIONS := ["macro_recorder"]

var failures := 0
var passes := 0


func check(label: String, ok: bool) -> void:
	if ok:
		passes += 1
		print("PASS  " + label)
	else:
		failures += 1
		print("FAIL  " + label)


func _initialize() -> void:
	var addons := DirAccess.get_directories_at("res://addons")
	var docks := 0
	for addon in addons:
		var ui_dir := "res://addons/%s/ui" % addon
		if not DirAccess.dir_exists_absolute(ui_dir):
			continue
		for file in DirAccess.get_files_at(ui_dir):
			if file.ends_with("_dock.gd"):
				docks += 1
				_smoke(addon, ui_dir.path_join(file))
	var probe := VBoxContainer.new()
	probe.add_child(Button.new())
	check("tooltip check catches an untipped button", _untipped(probe).size() == 1)
	probe.free()
	check("found a dock for every addon (%d docks, %d addons)" % [docks, addons.size()], docks == addons.size())
	print("%d passed, %d failed" % [passes, failures])
	quit(1 if failures > 0 else 0)


func _smoke(addon: String, path: String) -> void:
	var script: Script = load(path)
	if script == null or not script.can_instantiate():
		check("%s: dock script loads" % addon, false)
		return
	var dock: Node = script.new()
	root.add_child(dock)
	var untipped := _untipped(dock)
	check("%s: every interactive control has a tooltip%s" % [addon, "" if untipped.is_empty() else " (missing: %s)" % ", ".join(untipped)], untipped.is_empty())
	if addon in EDITOR_ONLY_ACTIONS:
		print("SKIP  %s: run action needs the editor; constructed only" % addon)
	elif dock.has_method("_on_run"):
		var before := _text(dock)
		dock.call("_on_run")
		var after := _text(dock)
		check("%s: run action produces output" % addon, after != before and after.strip_edges() != "")
	else:
		check("%s: dock has a run action" % addon, false)
	root.remove_child(dock)
	dock.free()


func _untipped(node: Node) -> Array:
	var out: Array = []
	if node is BaseButton or node is LineEdit or node is Range or node is TextEdit or node is ItemList or node is Tree:
		if node is Control and (node as Control).tooltip_text.strip_edges() == "" and not (node is ScrollBar):
			out.append("%s '%s'" % [node.get_class(), node.text if "text" in node else node.name])
	# Internal children (a SpinBox's LineEdit, a TextEdit's scroll bars) are
	# engine parts covered by their parent's tooltip, so they are not walked.
	for child in node.get_children():
		out.append_array(_untipped(child))
	return out


func _text(node: Node) -> String:
	var parts: PackedStringArray = []
	if node is RichTextLabel:
		parts.append((node as RichTextLabel).get_parsed_text())
	elif node is Label or node is TextEdit:
		parts.append(node.text)
	elif node is ItemList:
		parts.append(str((node as ItemList).item_count))
	elif node is Tree:
		parts.append(str((node as Tree).get_root() != null))
	for child in node.get_children():
		parts.append(_text(child))
	return "\n".join(parts)
