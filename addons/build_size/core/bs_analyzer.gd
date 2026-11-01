## Read-only inventory of the actual files in an unpacked build directory.
extends RefCounted

func run(root: String, max_file_bytes: int = 0, max_total_bytes: int = 0) -> Dictionary:
    if max_file_bytes < 0 or max_total_bytes < 0:
        return _result([], {}, {}, 0, [_issue("error", "invalid_budget", root, "Byte budgets must be non-negative.", "Use zero to disable a budget.")])
    var files: Array = []
    var issues: Array = []
    _walk(root, "", files, issues)
    var result := analyze(files, max_file_bytes, max_total_bytes, issues)
    # Attribute what is inside each Godot pack (standalone .pck, or a pack
    # embedded at the end of an executable) to the project paths it holds.
    var archives := {}
    for entry in files:
        var rel := str(entry["path"])
        var full := root.path_join(rel)
        var ext := rel.get_extension().to_lower()
        if ext == "pck" or (ext in ["exe", "x86_64", "arm64", ""] and _has_embedded_pck(full)):
            var pck := read_pck(full)
            if not pck["ok"]:
                result["issues"].append(_issue("warning", "pck_unreadable", rel, str(pck["error"]), "Inspect the pack with the Godot version that built it."))
                continue
            var groups := {}
            for inner in pck["files"]:
                var ipath := str(inner["path"])
                var local := ipath.trim_prefix("res://")
                var top := local.get_slice("/", 0) if local.contains("/") else "(root)"
                groups[top] = int(groups.get(top, 0)) + int(inner["bytes"])
                if max_file_bytes > 0 and int(inner["bytes"]) > max_file_bytes:
                    result["issues"].append(_issue("warning", "file_budget", "%s::%s" % [rel, ipath], "Packed file is %d bytes; limit is %d." % [inner["bytes"], max_file_bytes], "Review the asset or update its budget."))
            var inner_files: Array = pck["files"]
            inner_files.sort_custom(func(a, b): return a["bytes"] > b["bytes"] if a["bytes"] != b["bytes"] else a["path"] < b["path"])
            archives[rel] = {"format": pck["format"], "engine": pck["engine"], "embedded": pck["embedded"], "files": inner_files, "groups": groups, "bytes": pck["payload_bytes"]}
    result["archives"] = archives
    result["summary"]["issues"] = result["issues"].size()
    result["summary"]["packed_files"] = archives.values().reduce(func(acc, a): return acc + a["files"].size(), 0)
    return result


const PCK_MAGIC := 0x43504447 ## "GDPC"


func _has_embedded_pck(path: String) -> bool:
    var f := FileAccess.open(path, FileAccess.READ)
    if f == null or f.get_length() < 16:
        return false
    f.seek(f.get_length() - 4)
    var ok := f.get_32() == PCK_MAGIC
    f.close()
    return ok


## Read a Godot 4 pack directory without extracting anything.
## Supports format 2 (Godot 4.0-4.3: directory after the header, res:// paths)
## and format 3 (Godot 4.4+: directory at dir_offset, relative paths), as a
## standalone .pck or embedded at the end of an executable.
## -> {ok, error, format, engine, embedded, payload_bytes, files:[{path, bytes}]}
func read_pck(path: String) -> Dictionary:
    var out := {"ok": false, "error": "", "format": 0, "engine": "", "embedded": false, "payload_bytes": 0, "files": []}
    var f := FileAccess.open(path, FileAccess.READ)
    if f == null:
        out["error"] = "Cannot open the pack."
        return out
    var start := 0
    if f.get_length() < 4 or f.get_32() != PCK_MAGIC:
        if f.get_length() < 16:
            out["error"] = "Not a Godot pack."
            return out
        f.seek(f.get_length() - 12)
        var size := f.get_64()
        if f.get_32() != PCK_MAGIC or size <= 0 or size > f.get_length() - 12:
            out["error"] = "Not a Godot pack and no embedded pack found."
            return out
        start = f.get_length() - 12 - size
        out["embedded"] = true
        f.seek(start)
        if f.get_32() != PCK_MAGIC:
            out["error"] = "Embedded pack header is damaged."
            return out
    var version := f.get_32()
    var major := f.get_32()
    var minor := f.get_32()
    var patch := f.get_32()
    out["format"] = version
    out["engine"] = "%d.%d.%d" % [major, minor, patch]
    if version != 2 and version != 3:
        out["error"] = "Pack format %d is not supported (2 and 3 are)." % version
        return out
    var flags := f.get_32()
    if flags & 1:
        out["error"] = "The pack directory is encrypted; contents cannot be attributed."
        return out
    f.get_64() # file base
    var dir_offset := 0
    if version >= 3:
        dir_offset = f.get_64()
    for i in 16:
        f.get_32()
    if version >= 3:
        f.seek(start + dir_offset)
    var count := f.get_32()
    if count > 1000000:
        out["error"] = "Pack directory claims %d files; refusing to read." % count
        return out
    var payload := 0
    for i in count:
        if f.get_position() + 4 > f.get_length():
            out["error"] = "Pack directory is truncated."
            return out
        var length := f.get_32()
        if length > 4096:
            out["error"] = "Pack directory entry is malformed."
            return out
        var name := f.get_buffer(length).get_string_from_utf8()
        f.get_64() # offset
        var size := f.get_64()
        f.get_buffer(16) # md5
        f.get_32() # flags
        if not name.begins_with("res://"):
            name = "res://" + name
        payload += size
        (out["files"] as Array).append({"path": name, "bytes": size})
    out["payload_bytes"] = payload
    out["ok"] = true
    return out

func _walk(root: String, relative: String, files: Array, issues: Array) -> void:
    var current := root if relative.is_empty() else root.path_join(relative)
    var dir := DirAccess.open(current)
    if dir == null:
        issues.append(_issue("error", "scan_error", current, "Cannot open directory.", "Choose an existing readable build directory."))
        return
    dir.list_dir_begin()
    var name := dir.get_next()
    while name != "":
        if name != "." and name != "..":
            var path := name if relative.is_empty() else relative.path_join(name)
            if dir.is_link(name):
                issues.append(_issue("warning", "skipped_link", path, "Symbolic link or junction was not followed.", "Inspect the link target separately if it is part of the build."))
            elif dir.current_is_dir():
                _walk(root, path, files, issues)
            else:
                var file := FileAccess.open(root.path_join(path), FileAccess.READ)
                if file == null:
                    issues.append(_issue("error", "scan_error", path, "Cannot read file.", "Check permissions and retry the scan."))
                else:
                    files.append({"path": path, "bytes": file.get_length()})
        name = dir.get_next()
    dir.list_dir_end()

## File inventory rows use relative paths and integer byte counts.
func analyze(files: Array, max_file_bytes: int = 0, max_total_bytes: int = 0, initial_issues: Array = []) -> Dictionary:
    var issues: Array = initial_issues.duplicate(true)
    var groups := {}
    var extensions := {}
    var rows: Array = []
    var total := 0
    if max_file_bytes < 0 or max_total_bytes < 0:
        issues.append(_issue("error", "invalid_budget", "budgets", "Byte budgets must be non-negative.", "Use zero to disable a budget."))
        return _result(rows, groups, extensions, total, issues)
    for entry in files:
        if typeof(entry) != TYPE_DICTIONARY or typeof(entry.get("path")) != TYPE_STRING or str(entry.get("path", "")).is_empty() or typeof(entry.get("bytes")) != TYPE_INT or int(entry.get("bytes", -1)) < 0:
            issues.append(_issue("error", "invalid_entry", "inventory", "File entry needs a non-empty path and non-negative integer byte count.", "Correct the inventory input."))
            continue
        var path := str(entry["path"])
        var size := int(entry["bytes"])
        var group := path.get_slice("/", 0) if path.contains("/") else "(root)"
        var ext := path.get_extension().to_lower()
        if ext.is_empty():
            ext = "(no extension)"
        groups[group] = int(groups.get(group, 0)) + size
        extensions[ext] = int(extensions.get(ext, 0)) + size
        total += size
        rows.append({"path": path, "bytes": size, "group": group, "extension": ext})
        if max_file_bytes > 0 and size > max_file_bytes:
            issues.append(_issue("warning", "file_budget", path, "File is %d bytes; limit is %d." % [size, max_file_bytes], "Review the file or update its budget."))
    rows.sort_custom(func(a, b): return a["bytes"] > b["bytes"] if a["bytes"] != b["bytes"] else a["path"] < b["path"])
    if max_total_bytes > 0 and total > max_total_bytes:
        issues.append(_issue("warning", "total_budget", "build", "Scanned files total %d bytes; limit is %d." % [total, max_total_bytes], "Review build contents or update its budget."))
    return _result(rows, groups, extensions, total, issues)

func _issue(severity: String, kind: String, path: String, message: String, fix: String) -> Dictionary:
    return {"severity": severity, "kind": kind, "path": path, "message": message, "fix": fix}

func _result(rows: Array, groups: Dictionary, extensions: Dictionary, total: int, issues: Array) -> Dictionary:
    return {"summary": {"files": rows.size(), "bytes": total, "issues": issues.size()}, "files": rows, "groups": groups, "extensions": extensions, "issues": issues}

func to_json(result: Dictionary) -> String:
    return JSON.stringify(result, "  ")

func to_markdown(result: Dictionary) -> String:
    var lines: Array[String] = ["# Build Size Attribution", "", "Summary: " + str(result["summary"]), "", "## Largest files"]
    for row in result["files"]:
        lines.append("- `%s`: %d bytes" % [row["path"], row["bytes"]])
    lines.append_array(["", "## Top-level folders", ""])
    var groups: Array = result["groups"].keys()
    groups.sort()
    for group in groups:
        lines.append("- `%s`: %d bytes" % [group, result["groups"][group]])
    lines.append_array(["", "## Extensions", ""])
    var extensions: Array = result["extensions"].keys()
    extensions.sort()
    for ext in extensions:
        lines.append("- `%s`: %d bytes" % [ext, result["extensions"][ext]])
    var archives: Dictionary = result.get("archives", {})
    for pck in archives:
        var a: Dictionary = archives[pck]
        lines.append_array(["", "## Inside `%s` (pack format %d, Godot %s%s)" % [pck, a["format"], a["engine"], ", embedded" if a["embedded"] else ""], ""])
        var tops: Array = a["groups"].keys()
        tops.sort_custom(func(x, y): return a["groups"][x] > a["groups"][y])
        for top in tops:
            lines.append("- `%s/`: %d bytes" % [top, a["groups"][top]])
        lines.append("")
        for inner in a["files"].slice(0, 20):
            lines.append("- `%s`: %d bytes" % [inner["path"], inner["bytes"]])
    lines.append_array(["", "## Findings"])
    for issue in result["issues"]:
        lines.append("- **%s** `%s`: %s %s" % [issue["kind"], issue["path"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
