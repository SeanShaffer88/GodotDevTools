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


func scan() -> Dictionary:
    var files: Array[String] = []
    _walk("res://", files)
    files.sort()
    var issues: Array = []
    var by_hash: Dictionary = {}
    var total_bytes := 0
    var textures: Array = []
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
                if FileAccess.file_exists(imp_path):
                    var imp := _parse_import(imp_path)
                    mip = bool(imp.get("mipmaps/generate", true))
                var vram := estimated_vram_bytes(dims, mip)
                textures.append({"path": path, "size": dims, "bytes": size, "vram": vram})
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
    return {"summary": {"files": files.size(), "bytes": total_bytes, "textures": textures.size(),
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
    for i in result["issues"]:
        lines.append("- [%s] %s" % [i["severity"], i["message"]])
    return "\n".join(lines) + "\n"
