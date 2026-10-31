extends Node
## Scenario fixture: counts physics frames while ui_accept is held.

var count: int = 0


func _physics_process(_delta: float) -> void:
    if Input.is_action_pressed("ui_accept"):
        count += 1


func add(amount: int) -> void:
    count += amount
