extends Node2D

var velocity := Vector2.RIGHT * 600.0
var life := 1.5


func _physics_process(delta: float) -> void:
    position += velocity * delta
    life -= delta
    if life <= 0.0:
        queue_free()
