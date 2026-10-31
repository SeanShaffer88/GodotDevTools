## Visual Regression Testing - capture runner operation.
## The one-click shutter the compare side was waiting for: instantiates
## each listed scene in an offscreen SubViewport at each planned
## resolution, lets it settle for a few frames, and saves the PNG under
## the baseline naming scheme ("<scene>__<width>x<height>.png") so a
## capture run and the suite compare share one file layout. The planning
## and report-shaping parts are pure and headless-testable; the live
## viewport pass needs a rendering context (the editor dock or a running
## game) and is never exercised headless.
extends RefCounted

const Baselines := preload("res://addons/visual_regression/core/vrt_baselines.gd")

## Frames awaited per capture (one process + one physics frame each) so
## animations, layout and autoload-driven content settle before the shot.
var frames_to_settle: int = 2
var default_output_dir := "res://visual_current"


## Pure: the full output path of every entry of a capture plan, using the
## same naming the suite compare reads back.
func target_paths(plan: Array, out_dir: String = "") -> Array[String]:
    var dir := out_dir if out_dir != "" else default_output_dir
    var out: Array[String] = []
    for entry in plan:
        out.append(dir.path_join(str(entry.get("file_name", ""))))
    return out


## Pure: shape a capture pass into the report shape every tool shares
## (summary + issues with a plain-words fix per failure).
func capture_report(plan: Array, written: Array, failed: Array, out_dir: String = "") -> Dictionary:
    var issues: Array = []
    for f in failed:
        issues.append({"severity": "error", "kind": "capture_failed",
            "path": str(f.get("scene", "")),
            "message": "Could not capture %s at %s: %s." % [
                str(f.get("scene", "")), str(f.get("size", "")), str(f.get("reason", ""))],
            "fix": "Check the scene path exists, and run the capture in the editor or a real game window - a headless process has nothing to render."})
    return {"summary": {"planned": plan.size(), "written": written.size(),
            "failed": failed.size(), "output_dir": out_dir if out_dir != "" else default_output_dir},
        "written": written, "failed": failed, "issues": issues}


## Live pass: capture every plan entry under `host`, a Node inside a
## rendering tree (the editor dock passes itself; in a game, any node).
## Returns the capture_report for what was written and what failed.
func run_captures(host: Node, scene_paths: Array, out_dir: String = "", resolutions: Array = []) -> Dictionary:
    var planner = Baselines.new()
    var plan: Array = planner.capture_plan(scene_paths, resolutions)
    var dir := out_dir if out_dir != "" else default_output_dir
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
    var written: Array = []
    var failed: Array = []
    var viewport := SubViewport.new()
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    viewport.transparent_bg = false
    host.add_child(viewport)
    for entry in plan:
        var scene_path := str(entry.get("scene", ""))
        var size: Vector2i = entry.get("size", Vector2i(0, 0))
        if not ResourceLoader.exists(scene_path):
            failed.append({"scene": scene_path, "size": size, "reason": "scene_not_found"})
            continue
        var packed: PackedScene = load(scene_path)
        if packed == null:
            failed.append({"scene": scene_path, "size": size, "reason": "scene_not_loadable"})
            continue
        viewport.size = size
        var inst := packed.instantiate()
        viewport.add_child(inst)
        for _i in frames_to_settle:
            await host.get_tree().process_frame
            await host.get_tree().physics_frame
        await RenderingServer.frame_post_draw
        var img: Image = viewport.get_texture().get_image()
        var out_path := dir.path_join(str(entry.get("file_name", "")))
        if img != null and img.save_png(ProjectSettings.globalize_path(out_path)) == OK:
            written.append(out_path)
        else:
            failed.append({"scene": scene_path, "size": size, "reason": "save_failed"})
        inst.queue_free()
    viewport.queue_free()
    return capture_report(plan, written, failed, dir)
