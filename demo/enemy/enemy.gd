class_name PatrolEnemy
extends CharacterBody2D

enum State { PATROL, CHASE, IDLE }

var current_state: State = State.PATROL
var patrol_speed: float = 60.0
var patrol_target: Vector2 = Vector2(200, 0)


func _physics_process(_delta: float) -> void:
    match current_state:
        State.PATROL:
            patrol()
        State.CHASE:
            chase()
        State.IDLE:
            velocity = Vector2.ZERO


func patrol() -> void:
    velocity = (patrol_target - global_position).normalized() * patrol_speed


func chase() -> void:
    velocity = Vector2.ZERO
