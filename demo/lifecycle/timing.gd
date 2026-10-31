extends Node

var started_ms := 0


func _ready() -> void:
    started_ms = Time.get_ticks_msec()


func time_left() -> float:
    return 60.0 - (Time.get_ticks_msec() - started_ms) / 1000.0
