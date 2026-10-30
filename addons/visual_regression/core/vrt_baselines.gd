## Visual Regression Testing - baseline suite operation.
## A baseline set is a folder of approved PNG screenshots named
## "<scene>__<width>x<height>.png". A capture run produces the same names
## in a "current" folder. This operation pairs them up, compares each
## pair with vrt_compare.gd, and reports pass / fail / missing baseline /
## missing capture per pair - the suite result the editor dock and the
## CI command line both show.
extends RefCounted

const Compare := preload("res://addons/visual_regression/core/vrt_compare.gd")

var channel_tolerance: int = 8
var fail_fraction: float = 0.001
## Standard capture resolutions used when planning a capture run.
var standard_resolutions: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(1280, 720),
    Vector2i(1152, 648), Vector2i(800, 600), Vector2i(390, 844)]


## The capture plan for a list of scene paths: one entry per scene x
## resolution, with the baseline file name each capture must produce.
func capture_plan(scene_paths: Array, resolutions: Array = []) -> Array:
    var res_list: Array = resolutions if not resolutions.is_empty() else standard_resolutions
    var plan: Array = []
    for scene in scene_paths:
        var stem := str(scene).get_file().get_basename()
        for r in res_list:
            var size: Vector2i = r
            plan.append({"scene": scene, "size": size,
                "file_name": "%s__%dx%d.png" % [stem, size.x, size.y]})
    return plan


func _list_pngs(dir_path: String) -> Dictionary:
    var out: Dictionary = {}
    var dir := DirAccess.open(dir_path)
    if dir == null:
        return out
    dir.list_dir_begin()
    var name := dir.get_next()
    while name != "":
        if not dir.current_is_dir() and name.get_extension().to_lower() == "png":
            out[name] = dir_path.path_join(name)
        name = dir.get_next()
    dir.list_dir_end()
    return out


func run_suite(baseline_dir: String, current_dir: String) -> Dictionary:
    var baselines := _list_pngs(baseline_dir)
    var currents := _list_pngs(current_dir)
    var cmp = Compare.new()
    cmp.channel_tolerance = channel_tolerance
    cmp.fail_fraction = fail_fraction
    var comparisons: Array = []
    var issues: Array = []
    var passed := 0
    var failed := 0
    for name in baselines:
        if not currents.has(name):
            comparisons.append({"name": name, "verdict": "missing_capture"})
            issues.append({"severity": "error", "kind": "missing_capture", "path": baselines[name],
                "message": "No current capture for baseline %s - the scene was not captured at this resolution." % name,
                "fix": "Run the capture again, or remove the baseline if this scene/resolution is retired."})
            failed += 1
            continue
        var bi := Image.new()
        var ci := Image.new()
        if bi.load(baselines[name]) != OK or ci.load(currents[name]) != OK:
            comparisons.append({"name": name, "verdict": "error"})
            issues.append({"severity": "error", "kind": "unreadable_image", "path": baselines[name],
                "message": "Could not read the PNG for %s." % name,
                "fix": "Re-capture this scene; the file is damaged or not a PNG."})
            failed += 1
            continue
        var r: Dictionary = cmp.compare_images(bi, ci)
        r["name"] = name
        comparisons.append(r)
        if r["verdict"] == "pass":
            passed += 1
        else:
            failed += 1
            issues.append({"severity": "error", "kind": "visual_diff", "path": currents[name],
                "message": "%s differs from its approved baseline: %d pixels (%.2f%%), biggest change %d, region %s." % [
                    name, int(r.get("diff_pixels", 0)), float(r.get("diff_fraction", 0.0)) * 100.0,
                    int(r.get("max_delta", 0)), str(r.get("bbox", Rect2i()))],
                "fix": "Open the highlight image. If the change is intended, approve it by replacing the baseline; if not, it is a visual regression."})
    for name in currents:
        if not baselines.has(name):
            comparisons.append({"name": name, "verdict": "missing_baseline"})
            issues.append({"severity": "warning", "kind": "missing_baseline", "path": currents[name],
                "message": "Capture %s has no approved baseline yet." % name,
                "fix": "Review the capture and copy it into the baselines folder to approve it."})
    comparisons.sort_custom(func(a, b): return str(a["name"]) < str(b["name"]))
    return {"summary": {"comparisons": comparisons.size(), "passed": passed, "failed": failed,
            "baselines": baselines.size(), "captures": currents.size()},
        "comparisons": comparisons, "issues": issues}


## Approve a capture run: copy every current PNG over its baseline
## (used after a human has reviewed the highlight images).
func approve_all(baseline_dir: String, current_dir: String) -> int:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(baseline_dir))
    var currents := _list_pngs(current_dir)
    var n := 0
    for name in currents:
        if DirAccess.copy_absolute(ProjectSettings.globalize_path(currents[name]),
                ProjectSettings.globalize_path(baseline_dir.path_join(name))) == OK:
            n += 1
    return n


func to_json(result: Dictionary) -> String:
    var slim := {"summary": result["summary"], "issues": result["issues"], "comparisons": []}
    for c in result["comparisons"]:
        var d: Dictionary = {}
        for k in c:
            if k != "highlight":
                d[k] = c[k]
        slim["comparisons"].append(d)
    return JSON.stringify(slim, "\t")


func to_markdown(result: Dictionary) -> String:
    var s: Dictionary = result["summary"]
    var lines: Array[String] = ["# Visual Regression Report", "",
        "%d comparisons: %d passed, %d failed (%d baselines, %d captures)." % [
            s["comparisons"], s["passed"], s["failed"], s["baselines"], s["captures"]], ""]
    for c in result["comparisons"]:
        lines.append("- **%s** - %s%s" % [c["name"], c["verdict"],
            (" (%d px, %.2f%%)" % [int(c.get("diff_pixels", 0)), float(c.get("diff_fraction", 0.0)) * 100.0]) if c.has("diff_pixels") and int(c.get("diff_pixels", -1)) >= 0 else ""])
    if not (result["issues"] as Array).is_empty():
        lines.append("")
        lines.append("## Problems")
        for i in result["issues"]:
            lines.append("- [%s] %s" % [i["severity"], i["message"]])
    return "\n".join(lines) + "\n"
