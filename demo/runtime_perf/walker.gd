extends CharacterBody2D


func _process(_delta: float) -> void:
    velocity.x = 100.0
    move_and_slide()
