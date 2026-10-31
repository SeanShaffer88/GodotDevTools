extends SceneTree
const Analyzer := preload("res://addons/build_size/core/bs_analyzer.gd")
var passes := 0
var failures := 0

func check(label: String, ok: bool) -> void:
    if ok:
        passes += 1
        print("PASS  ", label)
    else:
        failures += 1
        print("FAIL  ", label)

func kinds(result: Dictionary) -> Array:
    var out: Array = []
    for issue in result["issues"]:
        out.append(issue["kind"])
    return out

func _init() -> void:
    var op = Analyzer.new()
    var fixture: Dictionary = op.run("res://demo/build_size", 1)
    check("fixture scans two files", fixture["summary"]["files"] == 2)
    check("file budget catches fixture", kinds(fixture).count("file_budget") == 2)
    check("root and folder accounted", fixture["groups"].has("(root)") and fixture["groups"].has("assets"))
    var rows := [{"path": "assets/a.PNG", "bytes": 30}, {"path": "main.pck", "bytes": 10}, {"path": "assets/b.png", "bytes": 20}]
    var result: Dictionary = op.analyze(rows, 20, 59)
    check("totals sum actual bytes", result["summary"]["bytes"] == 60)
    check("folder grouping sums", result["groups"]["assets"] == 50 and result["groups"]["(root)"] == 10)
    check("extension grouping ignores case", result["extensions"]["png"] == 50)
    check("file sorting largest first", result["files"][0]["path"] == "assets/a.PNG")
    check("budgets are strict", kinds(result).count("file_budget") == 1 and kinds(result).has("total_budget"))
    check("budget boundary passes", op.analyze(rows, 30, 60)["issues"].is_empty())
    check("zero disables budgets", op.analyze(rows)["issues"].is_empty())
    check("invalid budget reported", kinds(op.analyze(rows, -1)).has("invalid_budget"))
    check("invalid row reported", kinds(op.analyze([{"path": "x", "bytes": -2}])).has("invalid_entry"))
    check("missing directory reported", kinds(op.run("res://missing_build_size_fixture")).has("scan_error"))
    # Real packs made by this engine's PCKPacker (format 2 on 4.0-4.3, 3 on 4.4+).
    var build := "user://gdt_bs_build"
    DirAccess.make_dir_recursive_absolute(build)
    for leftover in DirAccess.get_files_at(build):
        DirAccess.remove_absolute(build.path_join(leftover))
    var sources := {"res://art/hero.png": "res://demo/assets/hero.png", "res://data/story.json": "res://demo/dialogue/story.json"}
    var packer := PCKPacker.new()
    packer.pck_start(build.path_join("game.pck"))
    for target in sources:
        packer.add_file(target, sources[target])
    packer.flush()
    var packed: Dictionary = op.run(build, 0)
    var arch: Dictionary = packed["archives"].get("game.pck", {})
    var sizes := {}
    for inner in arch.get("files", []):
        sizes[inner["path"]] = inner["bytes"]
    var expected_sizes := true
    for target in sources:
        expected_sizes = expected_sizes and int(sizes.get(target, -1)) == FileAccess.open(sources[target], FileAccess.READ).get_length()
    check("pack directory read with exact per-file sizes", arch.get("format", 0) in [2, 3] and sizes.size() == 2 and expected_sizes)
    check("pack contents grouped by top-level folder", arch["groups"].keys().size() == 2 and int(arch["groups"].get("art", -1)) == int(sizes["res://art/hero.png"]) and int(arch["groups"].get("data", -1)) == int(sizes["res://data/story.json"]))
    check("pack engine version recorded", str(arch.get("engine", "")).begins_with(str(Engine.get_version_info()["major"])))
    var pck_bytes := FileAccess.get_file_as_bytes(build.path_join("game.pck"))
    var exe := FileAccess.open(build.path_join("game.x86_64"), FileAccess.WRITE)
    exe.store_buffer(PackedByteArray([0x7F, 0x45, 0x4C, 0x46, 1, 2, 3, 4, 5, 6, 7, 8]))
    exe.store_buffer(pck_bytes)
    exe.store_64(pck_bytes.size())
    exe.store_32(0x43504447)
    exe.close()
    var junk := FileAccess.open(build.path_join("broken.pck"), FileAccess.WRITE)
    junk.store_string("this is not a pack at all, just text")
    junk.close()
    var all: Dictionary = op.run(build, 400)
    check("pack embedded in an executable is found and read", all["archives"].has("game.x86_64") and all["archives"]["game.x86_64"]["embedded"] and all["archives"]["game.x86_64"]["files"].size() == 2)
    check("unreadable pack reported, not fatal", kinds(all).has("pck_unreadable") and all["archives"].has("game.pck"))
    check("file budget applies inside packs", all["issues"].any(func(i): return i["kind"] == "file_budget" and str(i["path"]).contains("::res://")))
    check("markdown lists pack contents", op.to_markdown(all).contains("Inside `game.pck`"))
    check("markdown reports file", op.to_markdown(result).contains("assets/a.PNG"))
    check("json parses", JSON.parse_string(op.to_json(result)).has("groups"))
    print("Build Size Explorer TESTS: %d passed, %d failed" % [passes, failures])
    quit(1 if failures else 0)
