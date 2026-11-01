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
    var preset := {"importers": {"texture": {"mipmaps/generate": true, "compress/mode": 0}}}
    var preset_issues: Array = op.check_import_preset(["res://demo/import_preset/sample.cfg"], preset)
    _check("preset finds wrong mipmap setting", _kinds(preset_issues).has("preset_mismatch"))
    _check("matching numeric parameter accepted", preset_issues.size() == 1)
    var matching := {"importers": {"texture": {"mipmaps/generate": false, "compress/mode": 0.0}}}
    _check("matching import settings pass", op.check_import_preset(["res://demo/import_preset/sample.cfg"], matching).is_empty())
    _check("missing setting flagged", _kinds(op.check_import_preset(["res://demo/import_preset/sample.cfg"], {"importers": {"texture": {"does/not_exist": true}}})).has("preset_missing"))
    _check("unmatched importer flagged", _kinds(op.check_import_preset(["res://demo/import_preset/sample.cfg"], {"importers": {"audio": {"x": true}}})).has("preset_no_match"))
    _check("invalid preset rejected", _kinds(op.check_import_preset([], {})).has("preset_invalid"))
    _check("unreadable import flagged", _kinds(op.check_import_preset(["res://missing_import_metadata.cfg"], matching)).has("preset_read_error"))
    _check("texture total reported", int(r["summary"]["texture_estimate_bytes"]) > 0)
    var with_options: Dictionary = op.scan("res://demo/import_preset/rules.json", 1)
    _check("texture budget flagged", _kinds(with_options["issues"]).has("texture_budget"))
    _check("preset applies to real project imports", _kinds(with_options["issues"]).has("preset_mismatch"))
    var v1: Dictionary = op.platform_vram(Vector2i(1024, 1024), {"compress/mode": 2}, false)
    _check("VRAM compressed opaque: BC1 desktop, ETC2 RGB8 mobile at half a byte per pixel", v1["desktop"]["format"] == "BC1" and v1["mobile"]["format"] == "ETC2_RGB8" and v1["desktop"]["bytes"] == 524288 and v1["mobile"]["bytes"] == 524288)
    var v2: Dictionary = op.platform_vram(Vector2i(1024, 1024), {"compress/mode": 2}, true)
    _check("VRAM compressed with alpha: BC3 / ETC2 RGBA8 at one byte per pixel", v2["desktop"]["format"] == "BC3" and v2["mobile"]["format"] == "ETC2_RGBA8" and v2["desktop"]["bytes"] == 1048576)
    var v3: Dictionary = op.platform_vram(Vector2i(1024, 1024), {"compress/mode": 2, "compress/high_quality": true}, false)
    _check("high quality: BC7 / ASTC 4x4", v3["desktop"]["format"] == "BC7" and v3["mobile"]["format"] == "ASTC_4x4" and v3["mobile"]["bytes"] == 1048576)
    var v4: Dictionary = op.platform_vram(Vector2i(1024, 1024), {"compress/mode": 0, "mipmaps/generate": true}, true)
    _check("lossless uploads RGBA8; mipmaps add a third", v4["desktop"]["format"] == "RGBA8" and v4["desktop"]["bytes"] == 5592406)
    var v5: Dictionary = op.platform_vram(Vector2i(1024, 1024), {"compress/mode": 0, "process/size_limit": 512}, true)
    _check("size_limit scales the largest side down", v5["mobile"]["bytes"] == 512 * 512 * 4)
    var v6: Dictionary = op.platform_vram(Vector2i(10, 10), {"compress/mode": 2}, false)
    _check("block formats round sides up to 4 pixels", v6["desktop"]["bytes"] == 72)
    var v7: Dictionary = op.platform_vram(Vector2i(256, 256), {"compress/mode": 2, "compress/normal_map": 1}, false)
    _check("normal maps: BC5 / ETC2 RG11", v7["desktop"]["format"] == "BC5" and v7["mobile"]["format"] == "ETC2_RG11")
    var opaque := Image.create(8, 8, false, Image.FORMAT_RGB8)
    opaque.save_png("user://gdt_ahd_rgb.png")
    var alpha := Image.create(8, 8, false, Image.FORMAT_RGBA8)
    alpha.save_png("user://gdt_ahd_rgba.png")
    _check("PNG alpha detected from the header", not op.has_alpha("user://gdt_ahd_rgb.png") and op.has_alpha("user://gdt_ahd_rgba.png"))
    var plat: Dictionary = op.scan("", 0, {"mobile": 1})
    _check("platform totals reported and mobile budget flagged", int(plat["summary"]["texture_mobile_bytes"]) > 0 and _kinds(plat["issues"]).has("platform_texture_budget"))
    _check("unknown platform budget rejected", _kinds(op.scan("", 0, {"console": 5})["issues"]).has("invalid_budget"))
    _check("negative budget rejected", _kinds(op.scan("", -1)["issues"]).has("invalid_budget"))
    _check("malformed preset file flagged", _kinds(op.scan("res://missing_import_preset.json")["issues"]).has("preset_invalid"))
    _finish("AHD TESTS")


func _paths_of_kind(issues: Array, kind: String) -> Array:
    var out: Array = []
    for i in issues:
        if i["kind"] == kind:
            out.append(i["path"])
    return out
