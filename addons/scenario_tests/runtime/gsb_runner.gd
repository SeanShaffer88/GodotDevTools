## Gameplay Scenario Test Builder - runtime runner.
## Runs a scenario's steps against an instanced scene, one step per physics
## frame (waits count physics frames). Pressed actions are released when it
## finishes. Read `results` after `finished`.
extends Node

const Core := preload("res://addons/scenario_tests/core/gsb_scenario.gd")

signal finished

var results: Array = []
var done: bool = false
var _core = Core.new()
var _steps: Array = []
var _index: int = 0
var _wait: int = 0
var _scene: Node
var _pressed: Dictionary = {}


func start(scenario: Dictionary) -> void:
    var packed: Variant = load(str(scenario.get("scene", "")))
    if not packed is PackedScene:
        results.append({"step": 0, "ok": false, "kind": "step_error", "message": "Scene could not be loaded."})
        _finish()
        return
    _scene = packed.instantiate()
    add_child(_scene)
    _steps = scenario.get("steps", [])


func _physics_process(_delta: float) -> void:
    if done or _scene == null:
        return
    if _wait > 0:
        _wait -= 1
        return
    if _index >= _steps.size():
        _finish()
        return
    var s: Dictionary = _steps[_index]
    _index += 1
    _run_step(s, _index)


func _run_step(s: Dictionary, n: int) -> void:
    if s.has("frames"):
        _wait = max(0, int(s["frames"]) - 1)
    elif s.has("action"):
        var a := str(s["action"])
        if bool(s.get("press", true)):
            Input.action_press(a)
            _pressed[a] = true
        else:
            Input.action_release(a)
            _pressed.erase(a)
    elif s.has("call"):
        var node := _node(str(s["call"].get("node", ".")), n)
        if node != null:
            node.callv(str(s["call"].get("method", "")), s["call"].get("args", []))
    elif s.has("set"):
        var node2 := _node(str(s["set"].get("node", ".")), n)
        if node2 != null:
            node2.set(str(s["set"].get("property", "")), s["set"].get("value"))
    elif s.has("assert"):
        var c: Dictionary = s["assert"]
        var node3 := _node(str(c.get("node", ".")), n)
        if node3 != null:
            var actual: Variant = node3.get(str(c["property"]))
            var ok: bool = _core.compare(actual, str(c.get("op", "==")), c.get("value"))
            results.append({"step": n, "ok": ok, "kind": "assertion_failed", "message": "%s.%s %s %s (actual %s)" % [c.get("node", "."), c["property"], c.get("op", "=="), c.get("value"), actual]})


func _node(path: String, n: int) -> Node:
    var node: Node = _scene if path == "." else _scene.get_node_or_null(path)
    if node == null:
        results.append({"step": n, "ok": false, "kind": "step_error", "message": "Node %s not found in the scene." % path})
    return node


func _finish() -> void:
    for a in _pressed.keys():
        Input.action_release(a)
    _pressed.clear()
    done = true
    if _scene != null:
        _scene.queue_free()
    finished.emit()
