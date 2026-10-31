## Localization Matrix tests.
extends SceneTree

var _failures: Array[String] = []
var _passes: int = 0


func _check(label: String, ok: bool, evidence: String = "") -> void:
    if ok:
        _passes += 1
        print("PASS  ", label)
    else:
        _failures.append(label)
        print("FAIL  ", label, "  ", evidence)


func _finish(name: String) -> void:
    print("----")
    print(name, ": %d passed, %d failed" % [_passes, _failures.size()])
    quit(1 if not _failures.is_empty() else 0)


func _kinds(issues: Array) -> Array:
    var out: Array = []
    for i in issues:
        out.append(i["kind"])
    return out

const Matrix := preload("res://addons/l10n_matrix/core/lmx_matrix.gd")


func _init() -> void:
    var op = Matrix.new()
    var csv: Dictionary = op.parse_csv(FileAccess.get_file_as_string("res://demo/l10n/ui.csv"))
    _check("csv locales parsed", (csv["locales"] as Array) == ["en", "de", "fr"], str(csv["locales"]))
    _check("csv empty french cell kept empty", str((csv["entries"]["MENU_START"] as Dictionary)["fr"]) == "", str(csv["entries"]["MENU_START"]))
    var po: Dictionary = op.parse_po(FileAccess.get_file_as_string("res://demo/l10n/plurals.po"))
    _check("po locale and plural rule parsed", str(po["locale"]) == "de" and int(po["nplurals"]) == 3, str(po))
    _check("quoted csv cells survive", (op.csv_line("\"a,b\",c") as Array) == ["a,b", "c"], str(op.csv_line("\"a,b\",c")))
    var r: Dictionary = op.run()
    var kinds := _kinds(r["issues"])
    _check("missing french translation flagged (gate kind)", kinds.has("missing_translation"), str(r["issues"]))
    _check("plural mismatch flagged", kinds.has("plural_mismatch"))
    _check("length risk flagged", kinds.has("length_risk"))
    _check("untranslated tr() call flagged", kinds.has("untranslated_call"))
    _check("unused table key flagged", kinds.has("unused_key"))
    _check("to_markdown renders a title", op.to_markdown(r).begins_with("# "))
    _finish("Localization Matrix TESTS")
