## Fixture: a harness file that forgets to quit - the no_finish warning
## case. Deliberately broken behaviour, never executed (no test_
## prefix), so it cannot hang anything.
extends SceneTree


func _init() -> void:
    print("this file never calls quit()")
