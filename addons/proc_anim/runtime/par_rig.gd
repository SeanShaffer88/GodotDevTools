## Procedural Animation Rigging Helper - in-game rig node.
## A Node2D that solves and drives a two-bone limb (leg, arm, antenna)
## every frame: point bone1_path and bone2_path at the limb's bones, set
## the bone lengths, and either assign a target node to follow or call
## set_target() from game code. It uses the exact solvers the config
## validator checks (core/par_solvers.gd), so a rig that passes the
## config check behaves the same in game. Also exposes squash_stretch()
## keyframes for a sprite child and look_at for a head bone.
extends Node2D

const Solvers := preload("res://addons/proc_anim/core/par_solvers.gd")

@export var bone1_path: NodePath
@export var bone2_path: NodePath
@export var target_path: NodePath
## Bone lengths in pixels; keep them equal to the art or the foot drifts.
@export var upper_length: float = 24.0
@export var lower_length: float = 24.0
## +1 bends one way, -1 the other (knee forward vs backward).
@export var bend_sign: int = 1
@export var enabled: bool = true

var solvers = Solvers.new()


func _process(_delta: float) -> void:
    if not enabled:
        return
    var target := get_node_or_null(target_path)
    if target is Node2D:
        set_target((target as Node2D).global_position)


## Solve the limb toward a world-space point and place the bones.
## Returns the solver result (joint, end, reachable, error).
func set_target(target: Vector2) -> Dictionary:
    var result := solvers.solve_two_bone(global_position, target,
        upper_length, lower_length, bend_sign)
    var bone1 := get_node_or_null(bone1_path)
    var bone2 := get_node_or_null(bone2_path)
    if bone1 is Node2D:
        var b1 := bone1 as Node2D
        b1.global_position = global_position
        b1.global_rotation = ((result["joint"] as Vector2) - global_position).angle()
    if bone2 is Node2D:
        var b2 := bone2 as Node2D
        b2.global_position = result["joint"]
        b2.global_rotation = ((result["end"] as Vector2) - (result["joint"] as Vector2)).angle()
    return result


## Turn a node to face a world-space point (heads, turrets, eyes).
func look_at_point(node: Node2D, point: Vector2) -> void:
    node.global_rotation = solvers.look_at_angle(node.global_position, point)


## Apply squash-and-stretch keyframes to a sprite over time: call with
## the seconds since impact; returns the scale for that moment.
func squash_scale(impact_speed: float, t: float, frames: int = 12) -> Vector2:
    var keys := solvers.squash_stretch(impact_speed, 0.01, 8.0, frames)
    var f := clampf(t, 0.0, 1.0) * float(frames - 1)
    var i := clampi(int(floorf(f)), 0, frames - 1)
    return keys[i]["scale"]
