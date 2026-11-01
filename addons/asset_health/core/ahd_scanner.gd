## Asset Health Dashboard - project asset scan operation.
## Walks the project and reports: oversized textures (with an estimate
## of the video memory they will occupy), files that are byte-for-byte
## duplicates of each other, resources nothing references (unused),
## import settings that differ between files of the same kind (one
## texture with mipmaps off among many with them on behaves differently
## in game), and files large enough to hurt loading times.
## No editor APIs: the editor dashboard and the CI command line run the
## same scan.
extends RefCounted

var big_texture_pixels: int = 2048 * 2048 ## width*height above this = oversized
var big_file_bytes: int = 5 * 1024 * 1024
var slow_load_bytes: int = 20 * 1024 * 1024

const IMAGE_EXTS: Array[String] = ["png", "jpg", "jpeg", "webp", "svg", "bmp", "tga", "exr", "hdr"]
const SKIP_DIRS: Array[String] = [".godot", ".git", "addons"]


func _walk(dir_path: String, out: Array[String]) -> void:
    var dir := DirAccess.open(dir_path)
    if dir == null:
        return
    dir.list_dir_begin()
    var name := dir.get_next()
    while name != "":
        if name.begins_with("."):
            name = dir.get_next()
            continue
        var full := dir_path.path_join(name)
        if dir.current_is_dir():
            if not SKIP_DIRS.has(name):
                _walk(full, out)
        else:
            out.append(full)
        name = dir.get_next()
    dir.list_dir_end()


## Pixel dimensions from a PNG header (IHDR), or from Godot's Image
## loader for other formats. Vector2i(-1,-1) when unknown.
func image_dimensions(path: String) -> Vector2i:
    if path.get_extension().to_lower() == "png":
        var f := FileAccess.open(path, FileAccess.READ)
        if f == null or f.get_length() < 24:
            return Vector2i(-1, -1)
        f.seek(16)
        var wpx := int(f.get_32())
        var hpx := int(f.get_32())
        f.close()
        # PNG stores big-endian; Godot get_32 is little-endian on x86.
        return Vector2i(_swap32(wpx), _swap32(hpx))
    var img := Image.new()
    if img.load(path) == OK:
        return img.get_size()
    return Vector2i(-1, -1)


func _swap32(v: int) -> int:
    return ((v & 0xFF) << 24) | ((v & 0xFF00) << 8) | ((v >> 8) & 0xFF00) | ((v >> 24) & 0xFF)


func estimated_vram_bytes(size: Vector2i, mipmaps: bool) -> int:
    var bytes := size.x * size.y * 4
    if mipmaps:
        bytes = int(float(bytes) * 1.3333)
    return bytes


## Per-platform GPU memory estimate for one texture from its import settings,
## following Godot 4's texture importer (compress/mode 0 lossless, 1 lossy,
## 2 VRAM compressed, 3 VRAM uncompressed, 4 Basis Universal):
## - lossless, lossy and VRAM uncompressed upload as RGBA8 (4 bytes/pixel);
## - VRAM compressed: desktop BC1 without alpha / BC3 with alpha (BC7 when
##   compress/high_quality), mobile ETC2 RGB8 / ETC2 RGBA8 (ASTC 4x4 when
##   high_quality); normal maps BC5 / ETC2 RG11;
## - Basis Universal is transcoded at load to the same block formats.
## Block formats round each side up to 4 pixels; process/size_limit scales the
## largest side down; mipmaps add a third. These are estimates from the
## import settings, not measured device memory.
func platform_vram(size: Vector2i, params: Dictionary, has_alpha: bool) -> Dictionary:
    var dims := size
    var limit := int(params.get("process/size_limit", 0))
    if limit > 0 and maxi(dims.x, dims.y) > limit:
        var scale := float(limit) / float(maxi(dims.x, dims.y))
        dims = Vector2i(maxi(1, int(dims.x * scale)), maxi(1, int(dims.y * scale)))
    var mode := int(params.get("compress/mode", 0))
    var hq := bool(params.get("compress/high_quality", false))
    var normal := int(params.get("compress/normal_map", 0)) == 1
    var mip := bool(params.get("mipmaps/generate", false))
    var out := {}
    for platform in ["desktop", "mobile"]:
        var fmt := "RGBA8"
        var bpp := 4.0
        if mode == 2 or mode == 4:
            if normal:
                fmt = "BC5" if platform == "desktop" else "ETC2_RG11"
                bpp = 1.0
            elif hq:
                fmt = "BC7" if platform == "desktop" else "ASTC_4x4"
                bpp = 1.0
            elif has_alpha:
                fmt = "BC3" if platform == "desktop" else "ETC2_RGBA8"
                bpp = 1.0
            else:
                fmt = "BC1" if platform == "desktop" else "ETC2_RGB8"
                bpp = 0.5
        var w := dims.x
        var h := dims.y
        if fmt != "RGBA8":
            w = (w + 3) / 4 * 4
            h = (h + 3) / 4 * 4
        var bytes := float(w * h) * bpp
        if mip:
            bytes *= 4.0 / 3.0
        out[platform] = {"format": fmt, "bytes": int(ceil(bytes))}
    return out


## True when a PNG declares alpha (color type 4/6 or a tRNS chunk). Other
## formats: JPEG never has alpha; anything else is assumed to (larger estimate).
func has_alpha(path: String) -> bool:
    var ext := path.get_extension().to_lower()
    if ext in ["jpg", "jpeg"]:
        return false
    if ext != "png":
        return true
    var f := FileAccess.open(path, FileAccess.READ)
    if f == null or f.get_length() < 33:
        return true
    f.big_endian = true
    f.seek(25)
    var color_type := f.get_8()
    if color_type == 4 or color_type == 6:
        f.close()
        return true
    f.seek(33)
    while f.get_position() + 8 <= f.get_length():
        var length := int(f.get_32())
        var kind := f.get_buffer(4).get_string_from_ascii()
        if kind == "tRNS":
            f.close()
            return true
        if kind == "IDAT" or kind == "IEND":
            break
        f.seek(f.get_position() + length + 4)
    f.close()
    return false


func _parse_import(path: String) -> Dictionary:
    var cfg := ConfigFile.new()
    var out: Dictionary = {}
    if cfg.load(path) != OK:
        return out
    if cfg.has_section("params"):
        for k in cfg.get_section_keys("params"):
            out[k] = cfg.get_value("params", k)
    out["__dest"] = str(cfg.get_value("remap", "path", ""))
    return out


## Compare imported asset metadata against explicit importer-specific rules.
func check_import_preset(import_paths: Array, preset: Dictionary) -> Array:
    var issues: Array = []
    if typeof(preset.get("importers")) != TYPE_DICTIONARY or preset["importers"].is_empty():
        return [{"severity": "error", "kind": "preset_invalid", "path": "preset", "message": "Preset must define a nonempty importers object.", "fix": "Define importer names and expected parameter objects."}]
    var rules: Dictionary = preset["importers"]
    for importer in rules:
        if typeof(rules[importer]) != TYPE_DICTIONARY or rules[importer].is_empty():
            issues.append({"severity": "error", "kind": "preset_invalid", "path": str(importer), "message": "Importer rule must be a nonempty parameter object.", "fix": "Provide expected import parameters."})
    if not issues.is_empty():
        return issues
    var matched := 0
    for path in import_paths:
        var cfg := ConfigFile.new()
        if cfg.load(str(path)) != OK:
            issues.append({"severity": "error", "kind": "preset_read_error", "path": str(path), "message": "Cannot parse import metadata.", "fix": "Reimport the asset or repair the metadata."})
            continue
        var importer := str(cfg.get_value("remap", "importer", ""))
        if not rules.has(importer):
            continue
        matched += 1
        for key in rules[importer]:
            if not cfg.has_section_key("params", str(key)):
                issues.append({"severity": "warning", "kind": "preset_missing", "path": str(path), "message": "Expected import setting '%s' is missing." % key, "fix": "Review the preset and asset import settings."})
            else:
                var actual = cfg.get_value("params", str(key))
                var expected = rules[importer][key]
                if not _preset_equal(actual, expected):
                    issues.append({"severity": "warning", "kind": "preset_mismatch", "path": str(path), "message": "Import setting '%s' differs: expected %s, got %s." % [key, str(expected), str(actual)], "fix": "Review the intended preset and reimport if appropriate."})
    if matched == 0:
        issues.append({"severity": "warning", "kind": "preset_no_match", "path": "preset", "message": "No import metadata matched a configured importer.", "fix": "Check the preset importer names and project import state."})
    return issues

func _preset_equal(actual, expected) -> bool:
    var a := typeof(actual)
    var b := typeof(expected)
    if a in [TYPE_INT, TYPE_FLOAT] and b in [TYPE_INT, TYPE_FLOAT]:
        return float(actual) == float(expected)
    return a == b and actual == expected

func scan(preset_path: String = "", vram_budget: int = 0, platform_budgets: Dictionary = {}) -> Dictionary:
    var files: Array[String] = []
    _walk("res://", files)
    files.sort()
    var issues: Array = []
    var by_hash: Dictionary = {}
    var total_bytes := 0
    var textures: Array = []
    var desktop_total := 0
    var mobile_total := 0
    var import_by_ext: Dictionary = {} ## ext -> {setting_key: {value_string: [paths]}}
    # Reference sweep: every res:// literal in text files counts as a use.
    var referenced: Dictionary = {}
    var re := RegEx.new()
    re.compile("\"(res://[^\"]+)\"")
    for path in files:
        var ext := path.get_extension().to_lower()
        if ext in ["tscn", "tres", "gd", "cfg", "godot", "json", "import"]:
            var text := FileAccess.get_file_as_string(path)
            for m in re.search_all(text):
                referenced[m.get_string(1)] = true
        if ext == "godot":
            var cfg := ConfigFile.new()
            if cfg.load(path) == OK and cfg.has_section("application"):
                var main = cfg.get_value("application", "run/main_scene", "")
                if typeof(main) == TYPE_STRING and main != "":
                    referenced[main] = true
    for path in files:
        var ext := path.get_extension().to_lower()
        var size := 0
        var f := FileAccess.open(path, FileAccess.READ)
        if f != null:
            size = int(f.get_length())
            f.close()
        total_bytes += size
        if ext == "import":
            continue
        var hash := FileAccess.get_md5(path)
        if hash != "":
            if not by_hash.has(hash):
                by_hash[hash] = []
            (by_hash[hash] as Array).append(path)
        if IMAGE_EXTS.has(ext) and ext != "svg":
            var dims := image_dimensions(path)
            if dims.x > 0:
                var mip := true
                var imp_path := path + ".import"
                var imp_params: Dictionary = {}
                if FileAccess.file_exists(imp_path):
                    imp_params = _parse_import(imp_path)
                    mip = bool(imp_params.get("mipmaps/generate", true))
                var vram := estimated_vram_bytes(dims, mip)
                var plat := platform_vram(dims, imp_params, has_alpha(path))
                desktop_total += int(plat["desktop"]["bytes"])
                mobile_total += int(plat["mobile"]["bytes"])
                textures.append({"path": path, "size": dims, "bytes": size, "vram": vram,
                    "desktop": plat["desktop"], "mobile": plat["mobile"]})
                if dims.x * dims.y > big_texture_pixels:
                    issues.append({"severity": "warning", "kind": "oversized_texture", "path": path,
                        "message": "%s is %dx%d - about %.1f MB of video memory%s. Big textures load slowly and can exceed phone limits." % [
                            path, dims.x, dims.y, float(vram) / 1048576.0, " with mipmaps" if mip else ""],
                        "fix": "Shrink the source image, or set a max size in its import settings, unless it truly needs this resolution."})
        if size > slow_load_bytes:
            issues.append({"severity": "warning", "kind": "slow_load", "path": path,
                "message": "%s is %.1f MB - files this large stall loading screens." % [path, float(size) / 1048576.0],
                "fix": "Compress it, split it, or stream it instead of loading it up front."})
        elif size > big_file_bytes and not IMAGE_EXTS.has(ext):
            issues.append({"severity": "info", "kind": "large_file", "path": path,
                "message": "%s is %.1f MB." % [path, float(size) / 1048576.0],
                "fix": "Check it is not an uncompressed export or a leftover build file."})
        if FileAccess.file_exists(path + ".import"):
            var imp := _parse_import(path + ".import")
            if not import_by_ext.has(ext):
                import_by_ext[ext] = {}
            for k in imp:
                if k == "__dest":
                    continue
                var vs := str(imp[k])
                var by_key: Dictionary = import_by_ext[ext]
                if not by_key.has(k):
                    by_key[k] = {}
                if not by_key[k].has(vs):
                    by_key[k][vs] = []
                (by_key[k][vs] as Array).append(path)
        # Unused: not referenced, not the main scene chain root, not a doc.
        if not referenced.has(path) and ext not in ["md", "txt", "cfg", "godot", "gitignore", "json"]:
            if not path.begins_with("res://tests") and path.get_file() != "project.godot":
                issues.append({"severity": "info", "kind": "unused", "path": path,
                    "message": "%s is not referenced by any scene, script or resource." % path,
                    "fix": "If nothing loads it by a built-up string at run time, delete it to cut download size."})
    for hash in by_hash:
        var group: Array = by_hash[hash]
        if group.size() > 1:
            issues.append({"severity": "warning", "kind": "duplicate", "path": group[0],
                "message": "These files are byte-for-byte identical: %s. Each copy is downloaded and loaded separately." % ", ".join(group),
                "fix": "Keep one copy and point everything at it."})
    for ext in import_by_ext:
        var by_key: Dictionary = import_by_ext[ext]
        for k in by_key:
            var values: Dictionary = by_key[k]
            if values.size() > 1:
                var parts: Array = []
                for vs in values:
                    parts.append("%s x%d" % [vs, (values[vs] as Array).size()])
                issues.append({"severity": "warning", "kind": "import_inconsistent", "path": "",
                    "message": "Import setting '%s' for .%s files is inconsistent: %s. Files that look alike in the editor can behave differently in game." % [k, ext, ", ".join(parts)],
                    "fix": "Pick one setting for all .%s files of this kind and reimport." % ext})
    var texture_estimate := 0
    for texture in textures:
        texture_estimate += int(texture["vram"])
    if vram_budget < 0:
        issues.append({"severity": "error", "kind": "invalid_budget", "path": "", "message": "Texture budget cannot be negative.", "fix": "Use zero to disable or a positive byte budget."})
    elif vram_budget > 0 and texture_estimate > vram_budget:
        issues.append({"severity": "warning", "kind": "texture_budget", "path": "", "message": "Estimated uncompressed source texture total is %d bytes, exceeding the %d-byte budget." % [texture_estimate, vram_budget], "fix": "Review source dimensions and target-specific compression; verify actual device memory."})
    if preset_path != "":
        var preset_file := FileAccess.open(preset_path, FileAccess.READ)
        var parser := JSON.new()
        if preset_file == null or parser.parse(preset_file.get_as_text()) != OK or typeof(parser.data) != TYPE_DICTIONARY:
            issues.append({"severity": "error", "kind": "preset_invalid", "path": preset_path, "message": "Cannot read preset JSON object.", "fix": "Provide a readable importer preset JSON file."})
        else:
            var import_paths: Array = []
            for path in files:
                if path.get_extension().to_lower() == "import":
                    import_paths.append(path)
            issues.append_array(check_import_preset(import_paths, parser.data))
    for platform in platform_budgets:
        var budget := int(platform_budgets[platform])
        var total := desktop_total if platform == "desktop" else mobile_total
        if platform not in ["desktop", "mobile"] or budget < 0:
            issues.append({"severity": "error", "kind": "invalid_budget", "path": "", "message": "Platform budget '%s' is invalid." % platform, "fix": "Use desktop or mobile with a non-negative byte budget."})
        elif budget > 0 and total > budget:
            issues.append({"severity": "warning", "kind": "platform_texture_budget", "path": "", "message": "Estimated %s GPU texture total is %d bytes, over the %d-byte budget." % [platform, total, budget], "fix": "Lower process/size_limit, use VRAM compression, or disable mipmaps on UI textures; verify on target hardware."})
    return {"summary": {"files": files.size(), "bytes": total_bytes, "textures": textures.size(), "texture_estimate_bytes": texture_estimate,
            "texture_desktop_bytes": desktop_total, "texture_mobile_bytes": mobile_total,
            "issues": issues.size(),
            "duplicates": issues.filter(func(i): return i["kind"] == "duplicate").size(),
            "unused": issues.filter(func(i): return i["kind"] == "unused").size(),
            "oversized": issues.filter(func(i): return i["kind"] == "oversized_texture").size()},
        "issues": issues, "textures": textures}


func to_json(result: Dictionary) -> String:
    return JSON.stringify({"summary": result["summary"], "issues": result["issues"], "textures": result["textures"]}, "\t")


func to_markdown(result: Dictionary) -> String:
    var s: Dictionary = result["summary"]
    var lines: Array[String] = ["# Asset Health Report", "",
        "%d files, %.1f MB total, %d textures. %d problems: %d duplicates, %d unused, %d oversized." % [
            s["files"], float(s["bytes"]) / 1048576.0, s["textures"], s["issues"], s["duplicates"], s["unused"], s["oversized"]], ""]
    lines.append("Estimated uncompressed source texture total: %d bytes (not actual device memory)." % s.get("texture_estimate_bytes", 0))
    lines.append("Estimated GPU texture memory from import settings: desktop %d bytes, mobile %d bytes (estimates, not measured)." % [s.get("texture_desktop_bytes", 0), s.get("texture_mobile_bytes", 0)])
    for i in result["issues"]:
        lines.append("- [%s] %s" % [i["severity"], i["message"]])
    return "\n".join(lines) + "\n"
