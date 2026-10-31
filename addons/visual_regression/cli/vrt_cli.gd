## Visual Regression Testing - headless CLI.
##   godot --headless --path . --script res://addons/visual_regression/cli/vrt_cli.gd -- [options]
## Options: --baseline=<dir> --current=<dir> --out=<dir> --tolerance=<n>
##          --fail-fraction=<f> --fail-on=visual_diff,missing_capture (exit 2)
## On failure it also writes <name>.highlight.png next to the report.
extends SceneTree

const Baselines := preload("res://addons/visual_regression/core/vrt_baselines.gd")
const Review := preload("res://addons/visual_regression/core/vrt_review.gd")
const Compare := preload("res://addons/visual_regression/core/vrt_compare.gd")


func _init() -> void:
    var args := OS.get_cmdline_user_args()
    var baseline_dir := "res://visual_baselines"
    var current_dir := "res://visual_current"
    var op = Baselines.new()
    for arg in args:
        if arg.begins_with("--baseline="): baseline_dir = arg.trim_prefix("--baseline=")
        elif arg.begins_with("--current="): current_dir = arg.trim_prefix("--current=")
        elif arg.begins_with("--tolerance="): op.channel_tolerance = int(arg.trim_prefix("--tolerance="))
        elif arg.begins_with("--fail-fraction="): op.fail_fraction = float(arg.trim_prefix("--fail-fraction="))
    var result: Dictionary = op.run_suite(baseline_dir, current_dir)
    # Save highlight images for failing pairs.
    var cmp = Compare.new()
    cmp.channel_tolerance = op.channel_tolerance
    cmp.fail_fraction = op.fail_fraction
    var out_dir := "res://visual_reports"
    for arg in args:
        if arg.begins_with("--out="): out_dir = arg.trim_prefix("--out=")
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
    for c in result["comparisons"]:
        if c.get("verdict", "") == "fail" and c.has("highlight"):
            (c["highlight"] as Image).save_png(out_dir.path_join(str(c["name"]).get_basename() + ".highlight.png"))
    if args.has("--review-queue"):
        var queue: Dictionary = Review.new().build(result, baseline_dir, current_dir)
        if not _write(out_dir.path_join("review_queue.json"), JSON.stringify(queue, "  ")):
            quit(1)
            return
    _emit(op, result, args, "res://visual_reports", ["visual_diff", "missing_capture", "missing_baseline"])

func _write(path: String, content: String) -> bool:
    var f := FileAccess.open(path, FileAccess.WRITE)
    if f == null:
        printerr("Could not write ", path)
        return false
    f.store_string(content)
    f.close()
    return true


func _emit(op, result: Dictionary, args: Array, default_out: String, fail_kinds: Array) -> void:
    var out_dir := default_out
    var formats: Array[String] = ["json", "md"]
    for arg in args:
        if arg.begins_with("--out="):
            out_dir = arg.trim_prefix("--out=")
        elif arg.begins_with("--format="):
            formats.assign(arg.trim_prefix("--format=").split(","))
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
    if formats.has("json"):
        _write(out_dir.path_join("visual_regression.json"), op.to_json(result))
    if formats.has("md"):
        _write(out_dir.path_join("visual_regression.md"), op.to_markdown(result))
    print("VRT summary: ", result.get("summary", {}))
    for i in result.get("issues", []):
        print("VRT [", i.get("severity", "info"), "] ", i.get("message", ""))
    var failed := false
    var fail_on: Array[String] = []
    for arg in args:
        if arg.begins_with("--fail-on="):
            fail_on.assign(arg.trim_prefix("--fail-on=").split(","))
    for k in fail_kinds:
        if fail_on.has(k):
            for i in result.get("issues", []):
                if i.get("kind", "") == k:
                    failed = true
    if fail_on.has("errors"):
        for i in result.get("issues", []):
            if i.get("severity", "") == "error":
                failed = true
    if fail_on.has("issues") and not (result.get("issues", []) as Array).is_empty():
        failed = true
    quit(2 if failed else 0)
