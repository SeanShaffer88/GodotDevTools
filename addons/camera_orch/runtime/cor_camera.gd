## Camera Shake, Transition and Framing Orchestrator - in-game rig node.
## A Node2D camera rig that applies the orchestrator's pure maths
## (core/cor_motion.gd) to a live scene: deadzone framing around a
## target node (the camera does not move until the target leaves the
## deadzone, then follows to the nearest edge), smoothed by a lerp, plus
## deterministic seeded shakes - shake() with the same config and seed
## replays the identical shake on any platform, which is what makes a
## reported "weird shake" reproducible. Parent a Camera2D to this node;
## its offset carries the shake so framing stays clean.
extends Node2D

const Motion := preload("res://addons/camera_orch/core/cor_motion.gd")

@export var target_path: NodePath
## Deadzone size in pixels: the target moves freely inside this box.
@export var deadzone: Vector2 = Vector2(120, 80)
## Higher snaps to the framing target faster; 0 disables smoothing.
@export var smoothing: float = 8.0
@export var enabled: bool = true

var motion = Motion.new()

var _shake_config: Dictionary = {}
var _shake_started_at: float = -1.0


func _process(delta: float) -> void:
    if not enabled:
        return
    var target := get_node_or_null(target_path)
    if target is Node2D:
        var desired := motion.framing_position(global_position,
            (target as Node2D).global_position, deadzone)
        var blend := clampf(smoothing * delta, 0.0, 1.0)
        global_position = global_position.lerp(desired, blend)
    var offset := Vector2.ZERO
    if _shake_started_at >= 0.0:
        var t := _now() - _shake_started_at
        offset = motion.shake_sample(_shake_config, t)
        if t >= float(_shake_config.get("duration", 0.4)):
            _shake_started_at = -1.0
    for child in get_children():
        if child is Camera2D:
            (child as Camera2D).offset = offset


## Start a shake: {"amplitude": px, "frequency": hz, "duration": s,
## "seed": int}. Same config, same seed, same shake - every time.
func shake(config: Dictionary) -> void:
    _shake_config = config
    _shake_started_at = _now()


func stop_shake() -> void:
    _shake_started_at = -1.0


## Sample the current transition value (zoom, fade, anything keyed):
## {"from": a, "to": b, "duration": s, "ease": name} + seconds elapsed.
func transition_value(config: Dictionary, elapsed: float) -> float:
    return motion.transition_sample(config, elapsed)


func _now() -> float:
    return float(Time.get_ticks_msec()) / 1000.0
