extends Node
signal BadSignal
signal valid_signal

func _ready() -> void:
    add_to_group("BadRuntimeGroup")
    add_to_group("valid_group")
    # add_to_group("IgnoredComment")
