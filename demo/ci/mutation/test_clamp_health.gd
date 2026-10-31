extends SceneTree
## Deliberately weak test: never checks the exact boundaries.
const C := preload("res://demo/ci/mutation/clamp_health.gd")


func _init() -> void:
    var failed := 0
    if C.clamp_health(-5, 10) != 0:
        failed += 1
    if C.clamp_health(50, 10) != 10:
        failed += 1
    if C.clamp_health(5, 10) != 5:
        failed += 1
    if not C.is_dead(-1):
        failed += 1
    print("clamp TESTS: %d failed" % failed)
    quit(1 if failed else 0)
