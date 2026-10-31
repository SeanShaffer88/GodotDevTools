## Fixture: a passing harness-style test file for the runner's
## classifier and planner. Never executed by run_tests.sh (no test_
## prefix); it exists so discovery has something clean to find.
extends SceneTree

var _failures := 0


func _check(label: String, ok: bool) -> void:
    if not ok:
        _failures += 1
        printerr("FAIL: ", label)


func _init() -> void:
    _check("one plus one", 1 + 1 == 2)
    _finish()


func _finish() -> void:
    quit(2 if _failures > 0 else 0)
