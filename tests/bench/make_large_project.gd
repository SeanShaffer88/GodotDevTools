extends SceneTree
## Writes a synthetic large Godot project for timing the whole-project scanners.
## Usage: godot --headless --path . --script res://tests/bench/make_large_project.gd -- --out=/abs/dir [--scale=1]
## At scale 1: 2000 scripts, 1000 scenes, 400 textures, 300 resources, 100 JSON data files.
## Content is deterministic (seeded) so timings are comparable between runs.

var rng := RandomNumberGenerator.new()


func _initialize() -> void:
	var out := ""
	var scale := 1.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--scale="):
			scale = maxf(0.01, arg.trim_prefix("--scale=").to_float())
	if out == "" or not out.is_absolute_path():
		printerr("Pass --out=<absolute directory>.")
		quit(1)
		return
	rng.seed = 1337
	DirAccess.make_dir_recursive_absolute(out)
	_write(out.path_join("project.godot"), "config_version=5\n\n[application]\n\nconfig/name=\"Large Bench\"\n")
	var scripts := int(2000 * scale)
	var scenes := int(1000 * scale)
	var textures := int(400 * scale)
	var resources := int(300 * scale)
	var data := int(100 * scale)
	for i in scripts:
		_write(out.path_join("game/scripts/mod_%02d/s_%05d.gd" % [i % 40, i]), _script(i))
	for i in textures:
		var img := Image.create(64 + (i % 4) * 64, 64 + (i % 3) * 64, false, Image.FORMAT_RGBA8)
		img.fill(Color(rng.randf(), rng.randf(), rng.randf()))
		var path := out.path_join("game/art/set_%02d/t_%05d.png" % [i % 20, i])
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		img.save_png(path)
	for i in resources:
		_write(out.path_join("game/res/r_%05d.tres" % i), "[gd_resource type=\"Resource\" format=3]\n\n[resource]\nmetadata/value = %d\nmetadata/name = \"item_%d\"\n" % [i, i])
	for i in scenes:
		_write(out.path_join("game/scenes/area_%02d/sc_%05d.tscn" % [i % 30, i]), _scene(i, scripts, textures))
	for i in data:
		var rows := []
		for r in 50:
			rows.append({"id": "row_%d_%d" % [i, r], "weight": rng.randi_range(1, 100), "value": rng.randf_range(0, 500)})
		_write(out.path_join("game/data/d_%04d.json" % i), JSON.stringify({"rows": rows}, "  "))
	print("Wrote %d scripts, %d scenes, %d textures, %d resources, %d data files to %s" % [scripts, scenes, textures, resources, data, out])
	quit(0)


func _script(i: int) -> String:
	var lines := ["extends Node", "class_name Mod%05d" % i, "", "signal changed(value: int)", "", "@export var speed := %d.0" % rng.randi_range(1, 400), "@export var label: String = \"m%d\"" % i, "var _count := 0", ""]
	for f in 8:
		lines.append("func step_%d(delta: float) -> void:" % f)
		lines.append("\tvar total := 0.0")
		lines.append("\tfor k in %d:" % rng.randi_range(2, 9))
		lines.append("\t\tif k %% 2 == 0 and speed > %d:" % rng.randi_range(1, 300))
		lines.append("\t\t\ttotal += k * delta")
		lines.append("\t\telse:")
		lines.append("\t\t\ttotal -= delta")
		lines.append("\t_count += 1")
		lines.append("\tchanged.emit(_count)")
		lines.append("")
	if i % 7 == 0:
		lines.append("func untyped(a, b):")
		lines.append("\treturn get_node(\"Path/To/Child%d\")" % i)
	return "\n".join(lines) + "\n"


func _scene(i: int, scripts: int, textures: int) -> String:
	var s := rng.randi_range(0, scripts - 1)
	var t := rng.randi_range(0, textures - 1)
	var text := "[gd_scene load_steps=3 format=3]\n\n"
	text += "[ext_resource type=\"Script\" path=\"res://game/scripts/mod_%02d/s_%05d.gd\" id=\"1\"]\n" % [s % 40, s]
	text += "[ext_resource type=\"Texture2D\" path=\"res://game/art/set_%02d/t_%05d.png\" id=\"2\"]\n\n" % [t % 20, t]
	text += "[node name=\"Root%d\" type=\"Node2D\"]\nscript = ExtResource(\"1\")\n\n" % i
	for n in 20:
		var parent := "." if n < 4 else "N%d" % (n % 4)
		var kind: String = ["Sprite2D", "Area2D", "Label", "Node2D", "Timer"][n % 5]
		text += "[node name=\"N%d\" type=\"%s\" parent=\"%s\"]\n" % [n, kind, parent]
		if kind == "Sprite2D":
			text += "texture = ExtResource(\"2\")\n"
		elif kind == "Label":
			text += "text = \"Label %d\"\n" % n
		elif kind == "Area2D":
			text += "collision_mask = %d\n" % rng.randi_range(1, 0xFFFF)
		text += "\n"
	return text


func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()
