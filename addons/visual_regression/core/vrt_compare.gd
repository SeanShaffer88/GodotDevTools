## Visual Regression Testing - pixel comparison operation.
## Pure operation on two Images: counts differing pixels (per-channel
## tolerance), reports the percentage, the largest single-channel delta,
## the bounding box of the changed region, and can build a highlight
## image (changed pixels painted magenta over a dimmed copy of the new
## image) so a human can see exactly what moved.
extends RefCounted

var channel_tolerance: int = 8
## Fraction of pixels allowed to differ before the comparison fails.
var fail_fraction: float = 0.001


func compare_images(baseline: Image, current: Image) -> Dictionary:
    if baseline == null or current == null:
        return {"ok": false, "verdict": "error", "reason": "null image"}
    if baseline.get_size() != current.get_size():
        return {"ok": false, "verdict": "fail", "reason": "size_mismatch",
            "baseline_size": baseline.get_size(), "current_size": current.get_size(),
            "diff_pixels": -1, "diff_fraction": 1.0}
    var a := baseline.duplicate() as Image
    var b := current.duplicate() as Image
    a.convert(Image.FORMAT_RGBA8)
    b.convert(Image.FORMAT_RGBA8)
    var wpx := a.get_width()
    var hpx := a.get_height()
    var diff := 0
    var max_delta := 0
    var min_x := wpx
    var min_y := hpx
    var max_x := -1
    var max_y := -1
    var highlight := b.duplicate() as Image
    for y in hpx:
        for x in wpx:
            var pa := a.get_pixel(x, y)
            var pb := b.get_pixel(x, y)
            var d := maxi(maxi(absi(int(pa.r8) - int(pb.r8)), absi(int(pa.g8) - int(pb.g8))),
                maxi(absi(int(pa.b8) - int(pb.b8)), absi(int(pa.a8) - int(pb.a8))))
            if d > max_delta:
                max_delta = d
            if d > channel_tolerance:
                diff += 1
                min_x = mini(min_x, x)
                min_y = mini(min_y, y)
                max_x = maxi(max_x, x)
                max_y = maxi(max_y, y)
                highlight.set_pixel(x, y, Color(1, 0, 1, 1))
            else:
                var dim := highlight.get_pixel(x, y)
                highlight.set_pixel(x, y, Color(dim.r * 0.55, dim.g * 0.55, dim.b * 0.55, 1))
    var total := wpx * hpx
    var fraction := 0.0 if total == 0 else float(diff) / float(total)
    var passed := fraction <= fail_fraction
    var bbox := Rect2i()
    if diff > 0:
        bbox = Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)
    return {"ok": true, "verdict": "pass" if passed else "fail",
        "diff_pixels": diff, "total_pixels": total, "diff_fraction": fraction,
        "max_delta": max_delta, "bbox": bbox, "highlight": highlight}
