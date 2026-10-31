extends SceneTree
## Times every whole-project scanner's core (cores whose run() defaults to
## scanning "res://") on the project it runs in.
## Run inside a project made by make_large_project.gd with this repo's addons/
## and tests/ folders linked or copied in:
##   godot --headless --path <large> --script res://tests/bench/bench_cores.gd -- --out=/abs/bench.json
## Excluded: mutation_tester and suite_dispatcher (they start child processes).

const EXCLUDE := ["mutation_tester", "suite_dispatcher"]


func _initialize() -> void:
	var out := ""
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")
	var rows: Array = []
	for addon in DirAccess.get_directories_at("res://addons"):
		if addon in EXCLUDE or (only != "" and addon != only):
			continue
		var core_path := _core(addon)
		if core_path == "" or not FileAccess.get_file_as_string(core_path).contains("func run(input: String = \"res://\","):
			continue
		var core: Object = load(core_path).new()
		if not core.has_method("run"):
			continue
		var start := Time.get_ticks_usec()
		var result: Variant = core.callv("run", ["res://"])
		var ms := (Time.get_ticks_usec() - start) / 1000.0
		var summary: Variant = result.get("summary", {}) if result is Dictionary else {}
		var issues: int = result.get("issues", []).size() if result is Dictionary else -1
		rows.append({"addon": addon, "ms": snappedf(ms, 0.1), "issues": issues, "summary": str(summary).left(160)})
		print("%-24s %9.1f ms  %6d issues" % [addon, ms, issues])
	rows.sort_custom(func(a, b): return a["ms"] > b["ms"])
	if out != "":
		var f := FileAccess.open(out, FileAccess.WRITE)
		f.store_string(JSON.stringify({"engine": Engine.get_version_info()["string"], "rows": rows}, "  "))
		f.close()
	quit(0)


func _core(addon: String) -> String:
	var dir := "res://addons/%s/core" % addon
	if not DirAccess.dir_exists_absolute(dir):
		return ""
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".gd") and FileAccess.get_file_as_string(dir.path_join(file)).contains("func run("):
			return dir.path_join(file)
	return ""
