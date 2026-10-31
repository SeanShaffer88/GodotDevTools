extends RigidBody2D


func _process(delta: float) -> void:
    position += Vector2.RIGHT * 900.0 * delta
