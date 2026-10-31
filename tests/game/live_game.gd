extends Node2D
## Live-game session for the 16 runtime nodes. Runs as a real (windowed) game:
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tests/game/live_game.tscn
## Every node is added to the running tree and driven by real frames, real
## physics and real input events. Writes res://reports/live_game/live_game.json
## plus a screenshot, then quits with exit code 1 if any check failed.

const OUT_DIR := "res://reports/live_game"

var results: Array = []
var _counter := 0


func _ready() -> void:
	_run.call_deferred()


func check(node: String, label: String, ok: bool, detail: Variant = "") -> void:
	results.append({"node": node, "check": label, "ok": ok, "detail": str(detail)})
	print("%s  %s: %s %s" % ["PASS" if ok else "FAIL", node, label, "" if ok else str(detail)])


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	await frames(5)
	await _time_machine()
	await _leak_hunter()
	await _frame_spikes()
	await _camera()
	await _collision()
	await _network()
	await _behaviour_tree()
	await _proc_anim()
	await _seed_replay()
	await _state_coverage()
	await _signal_spy()
	await _pool_counter()
	await _input_fuzzer()
	await _rebind()
	await _offline_http()
	await _scenario()
	await _subtitle_layout()
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img != null:
		img.save_png(OUT_DIR.path_join("live_game.png"))
	var failed := results.filter(func(r): return not r["ok"]).size()
	var f := FileAccess.open(OUT_DIR.path_join("live_game.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"engine": Engine.get_version_info()["string"], "display": DisplayServer.get_name(), "video_adapter": RenderingServer.get_video_adapter_name(), "passed": results.size() - failed, "failed": failed, "results": results}, "  "))
	f.close()
	print("LIVE_GAME_DONE passed=%d failed=%d" % [results.size() - failed, failed])
	get_tree().quit(1 if failed > 0 else 0)


func _add(path: String) -> Node:
	var n: Node = load(path).new()
	add_child(n)
	return n


func _time_machine() -> void:
	var tm := _add("res://addons/time_machine/runtime/gstm_node.gd")
	_counter = 0
	tm.state_providers.append(func(): return {"counter": _counter})
	tm.state_restorers.append(func(s): _counter = int(s["counter"]))
	for i in 30:
		_counter += 1
		await frames(1)
	var snap: Dictionary = tm.rewind_to(10)
	check("time_machine", "records physics frames and rewinds state", not snap.is_empty() and _counter == int(snap["counter"]) and _counter < 30, snap)
	tm.queue_free()


func _leak_hunter() -> void:
	var watch := _add("res://addons/leak_hunter/runtime/mlh_watch.gd")
	watch.check_delay = 10
	watch.sweep_interval = 2
	var suspects: Array = []
	watch.orphan_suspect.connect(func(n, _f): suspects.append(n))
	var leaked := Node.new()
	leaked.name = "LeakedEnemy"
	add_child(leaked)
	watch.detach(leaked)
	var freed := Node.new()
	freed.name = "FreedEnemy"
	add_child(freed)
	watch.detach(freed)
	freed.free()
	for i in 30:
		await get_tree().process_frame
	var rep: Dictionary = watch.report()
	check("leak_hunter", "flags the detached node, not the freed one", suspects == ["LeakedEnemy"] and int(rep["freed"]) == 1, rep)
	leaked.free()
	watch.queue_free()


func _frame_spikes() -> void:
	var rec := _add("res://addons/frame_spikes/runtime/fts_recorder.gd")
	rec.mark("spike_start")
	for i in 20:
		await get_tree().process_frame
	var data: Dictionary = rec.log_data()
	var frames_logged: Array = data["frames"]
	check("frame_spikes", "logs real frame times with markers", frames_logged.size() >= 15 and frames_logged.any(func(f): return "spike_start" in f["markers"]) and frames_logged.all(func(f): return float(f["ms"]) > 0.0), "%d frames" % frames_logged.size())
	var path := "user://live_frame_log.json"
	check("frame_spikes", "saves its log", rec.save_log(path) == OK and FileAccess.file_exists(path))
	rec.queue_free()


func _camera() -> void:
	var target := Node2D.new()
	target.position = Vector2(600, 0)
	add_child(target)
	var rig: Node2D = load("res://addons/camera_orch/runtime/cor_camera.gd").new()
	var cam := Camera2D.new()
	rig.add_child(cam)
	add_child(rig)
	rig.target_path = rig.get_path_to(target)
	rig.shake({"amplitude": 12.0, "frequency": 20.0, "duration": 0.5, "seed": 3})
	var offsets: Array = []
	for i in 20:
		await get_tree().process_frame
		offsets.append(cam.offset)
	check("camera_orch", "follows its target past the deadzone", rig.global_position.x > 1.0, rig.global_position)
	check("camera_orch", "shake moves the Camera2D offset", offsets.any(func(o): return o.length() > 0.01), offsets.slice(0, 3))
	rig.queue_free()
	target.queue_free()


func _collision() -> void:
	var a := Area2D.new()
	a.collision_mask = 0b100
	var sa := CollisionShape2D.new()
	sa.shape = CircleShape2D.new()
	a.add_child(sa)
	var counter: Node = load("res://addons/collision_matrix/runtime/cmv_counter.gd").new()
	a.add_child(counter)
	add_child(a)
	# A moving kinematic body: Godot does not re-pair a teleported StaticBody2D with areas.
	var b := CharacterBody2D.new()
	b.collision_layer = 0b100
	var sb := CollisionShape2D.new()
	sb.shape = CircleShape2D.new()
	b.add_child(sb)
	b.position = Vector2(400, 400)
	add_child(b)
	await frames(3)
	b.position = a.position
	await frames(6)
	check("collision_matrix", "counts a real physics contact on layer bit 2", int(counter.counts.get(2, 0)) >= 1, counter.counts)
	a.queue_free()
	b.queue_free()


func _network() -> void:
	var proxy := _add("res://addons/network_sim/runtime/mns_proxy.gd")
	proxy.latency_ticks = 4
	proxy.jitter_ticks = 0
	proxy.loss_fraction = 0.0
	var got: Array = []
	proxy.message_delivered.connect(func(m): got.append(m))
	proxy.send({"id": 1})
	await frames(2)
	var early := got.size()
	await frames(8)
	check("network_sim", "delivers after the configured latency, not before", early == 0 and got.size() == 1, {"early": early, "late": got.size()})
	proxy.queue_free()


func _behaviour_tree() -> void:
	var agent: Node = load("res://addons/bt_debugger/runtime/btd_agent.gd").new()
	agent.definition_path = "res://demo/ai/guard_bt.json"
	agent.ticks_per_second = 30.0
	add_child(agent)
	var changes: Array = []
	agent.state_changed.connect(func(a, b): changes.append([a, b]))
	await frames(10)
	var idle_ok: bool = agent.current_state == "idle" and agent.load_errors().is_empty() and agent.trace.size() > 0
	agent.blackboard["noise_level"] = 0.9
	await frames(10)
	check("bt_debugger", "ticks on real frames and changes state from the blackboard", idle_ok and not changes.is_empty() and changes[0][0] == "idle", {"state": agent.current_state, "changes": changes})
	agent.queue_free()


func _proc_anim() -> void:
	var rig: Node2D = load("res://addons/proc_anim/runtime/par_rig.gd").new()
	var b1 := Node2D.new()
	var b2 := Node2D.new()
	var tgt := Node2D.new()
	add_child(rig)
	rig.add_child(b1)
	rig.add_child(b2)
	add_child(tgt)
	tgt.global_position = rig.global_position + Vector2(30, 10)
	rig.bone1_path = rig.get_path_to(b1)
	rig.bone2_path = rig.get_path_to(b2)
	rig.target_path = rig.get_path_to(tgt)
	await get_tree().process_frame
	await get_tree().process_frame
	var end: Vector2 = b2.global_position + Vector2.from_angle(b2.global_rotation) * float(rig.lower_length)
	check("proc_anim", "two-bone IK reaches a reachable target", end.distance_to(tgt.global_position) < 0.5, end)
	rig.queue_free()
	tgt.queue_free()


func _seed_replay() -> void:
	var rng := _add("res://addons/seed_replay/runtime/sdr_rng.gd")
	rng.reseed(42)
	var first: Array = []
	for i in 50:
		first.append(rng.randi_range(1, 6))
		if i % 10 == 0:
			rng.log_event("roll", str(first[-1]))
		await get_tree().process_frame
	var verify: Dictionary = rng.verify_self()
	rng.reseed(42)
	var second: Array = []
	for i in 50:
		second.append(rng.randi_range(1, 6))
	check("seed_replay", "same seed replays the same rolls across frames", first == second, first.slice(0, 5))
	check("seed_replay", "its own run log verifies", (verify["issues"] as Array).is_empty() and int(verify["summary"]["prng_calls"]) == 50, verify["summary"])
	rng.queue_free()


func _state_coverage() -> void:
	var cov := _add("res://addons/state_coverage/runtime/coverage_node.gd")
	cov.start_sequence()
	for pair in [["idle", "walk"], ["walk", "run"], ["run", "idle"]]:
		cov.record_transition(pair[0], pair[1])
		await get_tree().process_frame
	var snap: Dictionary = cov.snapshot()
	check("state_coverage", "records transitions during play", str(snap).contains("walk") and str(snap).contains("run"), snap)
	cov.queue_free()


func _signal_spy() -> void:
	var bus := _add("res://addons/signal_spy/runtime/sgs_bus.gd")
	bus.fired.connect(func(e):
		if e["signal"] == "hit":
			bus.emit_tracked("died", "Enemy")
		bus.note_handled(e["signal"], "HUD"))
	bus.emit_tracked("hit", "Player", "10")
	await get_tree().process_frame
	var s: Dictionary = bus.session()
	var handled: Array = bus.events.filter(func(e): return e["kind"] == "handle" and e["listener"] == "HUD")
	var cascade: Array = bus.events.filter(func(e): return e["kind"] == "emit" and e["signal"] == "died" and e["parent_fire"] != "")
	check("signal_spy", "records emits, handlers and the cascade parent", handled.size() == 2 and cascade.size() == 1, s)
	bus.queue_free()


func _pool_counter() -> void:
	var pc := _add("res://addons/pool_advisor/runtime/opa_counter.gd")
	for i in 12:
		pc.record("res://demo/pooling/bullet.tscn", "spawned")
		await get_tree().process_frame
	var snap: Dictionary = pc.snapshot()
	check("pool_advisor", "counts spawns over real frames", int(snap["scenes"]["res://demo/pooling/bullet.tscn"]["spawned"]) == 12 and float(snap["seconds"]) > 0.0, snap)
	pc.queue_free()


func _input_fuzzer() -> void:
	var player := _add("res://addons/input_fuzzer/runtime/isf_player.gd")
	var seen := {"pressed": 0, "released": 0}
	var listener := InputListener.new()
	listener.on_event = func(e: InputEvent):
		if e.is_action("ui_accept"):
			seen["pressed" if e.is_pressed() else "released"] += 1
	add_child(listener)
	var done := [false]
	player.finished.connect(func(): done[0] = true)
	player.play({"steps": [{"frame": 2, "action": "ui_accept", "hold": 3}, {"frame": 8, "action": "ui_accept", "hold": 1}]})
	await frames(15)
	check("input_fuzzer", "replays presses and releases through the input pipeline", done[0] and seen["pressed"] == 2 and seen["released"] == 2, seen)
	listener.queue_free()
	player.queue_free()


func _rebind() -> void:
	InputMap.add_action("gdt_live_jump")
	var rb: Node = load("res://addons/input_matrix/runtime/imx_rebind.gd").new()
	var actions: Array[String] = ["gdt_live_jump"]
	rb.rebindable_actions = actions
	add_child(rb)
	var done: Array = []
	rb.rebind_done.connect(func(a, e): done.append(a))
	rb.start_rebind("gdt_live_jump")
	var key := InputEventKey.new()
	key.keycode = KEY_J
	key.physical_keycode = KEY_J
	key.pressed = true
	Input.parse_input_event(key)
	await frames(3)
	var events := InputMap.action_get_events("gdt_live_jump")
	check("input_matrix", "rebinds an action from a real key event", done == ["gdt_live_jump"] and events.size() == 1 and (events[0] as InputEventKey).physical_keycode == KEY_J, events)
	rb.queue_free()
	InputMap.erase_action("gdt_live_jump")


func _offline_http() -> void:
	var http := _add("res://addons/offline_harness/runtime/ocn_http.gd")
	http.profile = {"seed": 1, "rules": [{"match": "*", "fault": "offline", "rate": 1.0}]}
	var got: Array = []
	http.request_completed.connect(func(r, c, _h, _b): got.append([r, c]))
	http.request("https://example.invalid/api")
	await frames(3)
	http.profile = {"seed": 1, "rules": [{"match": "*", "fault": "http_error", "status": 503, "rate": 1.0}]}
	http.request("https://example.invalid/api")
	await frames(3)
	check("offline_harness", "injects offline and HTTP-error faults without touching the network", got == [[HTTPRequest.RESULT_CANT_CONNECT, 0], [HTTPRequest.RESULT_SUCCESS, 503]], got)
	http.queue_free()


func _scenario() -> void:
	var runner := _add("res://addons/scenario_tests/runtime/gsb_runner.gd")
	var scenario: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://demo/testing/scenario/hold_and_add.json"))
	runner.start(scenario)
	for i in 120:
		await frames(1)
		if runner.done:
			break
	var asserts: Array = runner.results.filter(func(r): return str(r.get("kind", "")).contains("assert") or r.has("ok"))
	var fails: Array = runner.results.filter(func(r): return not bool(r.get("ok", true)))
	# The fixture's last assert (count == 999) fails on purpose.
	check("scenario_tests", "holds input on real frames; passes real asserts, catches the planted failure", runner.done and fails.size() == 1, runner.results)
	runner.queue_free()


## Not a runtime node: cross-checks the subtitle auditor's layout measure
## against a real Label rendered in this window with the same font and width.
func _subtitle_layout() -> void:
	var audit = load("res://addons/subtitle_audit/core/sub_audit.gd").new()
	var lay: Dictionary = audit._layout({"font_size": 32, "layout_width": 640, "safe_area": 0.9, "max_lines": 2})
	var samples := ["Short.", "Two words", "A medium length subtitle line that probably wraps once at this width", "This line keeps going far past what any reasonable subtitle box could hold at this size and it really should wrap onto several lines", "a\nb\nc"]
	var mismatches: Array = []
	for sample in samples:
		var label := Label.new()
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		label.add_theme_font_size_override("font_size", 32)
		label.custom_minimum_size = Vector2(float(lay["box"]), 0)
		label.size = Vector2(float(lay["box"]), 0)
		label.text = sample
		add_child(label)
		await get_tree().process_frame
		await get_tree().process_frame
		var rendered := label.get_line_count()
		var measured := int(audit.measure(sample, lay)["lines"])
		if rendered != measured:
			mismatches.append({"text": sample.left(30), "label": rendered, "measure": measured})
		label.queue_free()
	check("subtitle_audit", "layout line counts match a rendered Label", mismatches.is_empty(), mismatches)


class InputListener extends Node:
	var on_event: Callable
	func _input(event: InputEvent) -> void:
		if on_event.is_valid():
			on_event.call(event)
