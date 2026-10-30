## Visual Regression tests.
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

const Compare := preload("res://addons/visual_regression/core/vrt_compare.gd")
const Baselines := preload("res://addons/visual_regression/core/vrt_baselines.gd")


func _img(color: Color) -> Image:
    var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
    img.fill(color)
    return img


func _init() -> void:
    var cmp = Compare.new()
    var a := _img(Color(0.25, 0.5, 0.75))
    var r1: Dictionary = cmp.compare_images(a, a.duplicate())
    _check("identical images pass", r1["verdict"] == "pass" and int(r1["diff_pixels"]) == 0, str(r1))
    var b := _img(Color(0.25, 0.5, 0.75))
    b.set_pixel(3, 4, Color(1, 0, 0))
    var r2: Dictionary = cmp.compare_images(a, b)
    _check("one changed pixel counted", int(r2["diff_pixels"]) == 1, str(r2.get("diff_pixels")))
    _check("changed region bbox is that pixel", (r2["bbox"] as Rect2i) == Rect2i(3, 4, 1, 1), str(r2.get("bbox")))
    _check("highlight paints changed pixel magenta", (r2["highlight"] as Image).get_pixel(3, 4) == Color(1, 0, 1, 1))
    _check("1/64 pixels over the 0.1% allowance fails", r2["verdict"] == "fail")
    var c := _img(Color(0.25, 0.5, 0.75))
    c.set_pixel(0, 0, Color(0.25 + 4.0 / 255.0, 0.5, 0.75))
    var r3: Dictionary = cmp.compare_images(a, c)
    _check("change inside channel tolerance passes", int(r3["diff_pixels"]) == 0 and r3["verdict"] == "pass", str(r3))
    var small := Image.create(4, 4, false, Image.FORMAT_RGBA8)
    var r4: Dictionary = cmp.compare_images(a, small)
    _check("size mismatch fails with reason", r4["verdict"] == "fail" and str(r4.get("reason", "")) == "size_mismatch")
    var op = Baselines.new()
    var plan: Array = op.capture_plan(["res://demo/ui/hud.tscn"], [Vector2i(320, 240)])
    _check("capture plan names files by scene and size", plan.size() == 1 and str(plan[0]["file_name"]) == "hud__320x240.png", str(plan))
    var suite: Dictionary = op.run_suite("res://demo/visual/baselines", "res://demo/visual/current")
    _check("suite: identical pair passes", int(suite["summary"]["passed"]) == 1, str(suite["summary"]))
    _check("suite: changed pair fails", int(suite["summary"]["failed"]) == 1, str(suite["summary"]))
    var menu: Dictionary = {}
    var extra_seen := false
    for comp in suite["comparisons"]:
        if comp["name"] == "menu__320x240.png":
            menu = comp
        if comp["name"] == "extra__320x240.png" and comp["verdict"] == "missing_baseline":
            extra_seen = true
    _check("suite: menu diff is exactly the 16 changed pixels", int(menu.get("diff_pixels", -1)) == 16, str(menu.get("diff_pixels")))
    _check("suite: unapproved capture reported", extra_seen)
    _finish("VRT TESTS")
