extends Area2D

## A door interaction: the player walks up and interacts to open it.
var interaction_prompt: String = "Press E to open"
var is_open: bool = false


func interact() -> void:
    is_open = not is_open


func can_interact() -> bool:
    return true
