## Asset Health tests.
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

const Scanner := preload("res://addons/asset_health/core/ahd_scanner.gd")


func _init() -> void:
    var op = Scanner.new()
    _check("PNG dimensions read from header", op.image_dimensions("res://demo/assets/hero.png") == Vector2i(256, 256),
        str(op.image_dimensions("res://demo/assets/hero.png")))
    _check("big PNG dimensions", op.image_dimensions("res://demo/assets/big.png") == Vector2i(3000, 2000))
    _check("VRAM estimate without mipmaps", op.estimated_vram_bytes(Vector2i(100, 50), false) == 20000)
    _check("VRAM estimate with mipmaps is larger", op.estimated_vram_bytes(Vector2i(100, 50), true) > 20000)
    var r: Dictionary = op.scan()
    var kinds := _kinds(r["issues"])
    _check("oversized texture found (3000x2000)", kinds.has("oversized_texture"), str(kinds))
    _check("duplicate files found (hero_copy)", kinds.has("duplicate"))
    _check("unused asset found (orphan)", kinds.has("unused"))
    _check("import inconsistency found (mipmaps on/off)", kinds.has("import_inconsistent"))
    var dup_text := ""
    var unused_text := ""
    for i in r["issues"]:
        if i["kind"] == "duplicate": dup_text += i["message"] + " | "
        if i["kind"] == "unused" and str(i["path"]).contains("orphan"): unused_text = i["message"]
    _check("duplicate report names both copies", dup_text.contains("hero.png") and dup_text.contains("hero_copy.png"), dup_text)
    _check("used texture is not flagged unused", not _paths_of_kind(r["issues"], "unused").has("res://demo/assets/hero.png"))
    _finish("AHD TESTS")


func _paths_of_kind(issues: Array, kind: String) -> Array:
    var out: Array = []
    for i in issues:
        if i["kind"] == kind:
            out.append(i["path"])
    return out
