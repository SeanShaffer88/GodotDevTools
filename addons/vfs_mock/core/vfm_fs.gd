## Cross-Platform Virtual Filesystem Mock - resolution operation.
## Every platform's filesystem has different rules, and the difference
## only bites after export: Windows is case-insensitive and reserves
## device names, Linux and Android are case-sensitive, iOS sandboxes
## the bundle read-only, and Windows path length still bites at 260.
## This core models those rules as data - four profiles - and resolves
## file operations against them: a path that works on Windows but 404s
## on Linux (case_mismatch), ".." segments that escape the sandbox
## (sandbox_escape/path_traversal), writes into read-only roots
## (permission_denied), reserved names and forbidden characters. It
## also audits project scripts for hardcoded platform-isms (backslash
## paths, drive letters). No real files are touched; the mock answers
## from the project's actual res:// listing so the verdicts are real.
extends RefCounted

const PROFILES: Dictionary = {
    "linux": {"case_sensitive": true, "forbidden": [], "reserved": [],
        "max_path": 4096, "read_only_roots": []},
    "windows": {"case_sensitive": false, "forbidden": ["<", ">", ":", "\"", "|", "?", "*"],
        "reserved": ["CON", "PRN", "AUX", "NUL", "COM1", "COM2", "COM3", "COM4",
            "LPT1", "LPT2", "LPT3"],
        "max_path": 260, "read_only_roots": []},
    "android": {"case_sensitive": true, "forbidden": [], "reserved": [],
        "max_path": 4096, "read_only_roots": ["res://"]},
    "ios": {"case_sensitive": true, "forbidden": [], "reserved": [],
        "max_path": 1024, "read_only_roots": ["res://"]},
}


## Split a path into (root, segments) where root is "res:", "user:" or "".
func split_path(path: String) -> Dictionary:
    var root := ""
    var rest := path
    if path.begins_with("res://"):
        root = "res://"
        rest = path.substr(6)
    elif path.begins_with("user://"):
        root = "user://"
        rest = path.substr(7)
    var segments := rest.split("/") if rest != "" else []
    return {"root": root, "segments": segments}


## The one operation: resolve one request {op: read|write|list, path}
## under one profile, given the set of real file paths.
func resolve(request: Dictionary, profile_name: String, files: Array) -> Array:
    var issues: Array = []
    var profile: Dictionary = PROFILES.get(profile_name, PROFILES["linux"])
    var path := str(request.get("path", ""))
    var op := str(request.get("op", "read"))
    var split := split_path(path)
    var root := str(split["root"])
    var segments: Array = split["segments"]
    var escapes := false
    var depth := 0
    for seg in segments:
        var s := str(seg)
        if s == "..":
            depth -= 1
            if depth < 0:
                escapes = true
        elif s != "." and s != "":
            depth += 1
    if escapes:
        issues.append({"severity": "error", "kind": "sandbox_escape", "path": path,
            "message": "'%s' climbs above its root - on every profile this leaves the sandbox." % path,
            "fix": "Keep '..' out of runtime paths; build from a trusted root with path_join."})
    elif ".." in segments.map(func(s): return str(s)):
        issues.append({"severity": "warning", "kind": "path_traversal", "path": path,
            "message": "'%s' contains '..' segments; they resolve differently per platform once symlinks or packing are involved." % path,
            "fix": "Normalize at build time, not at runtime."})
    if op == "write":
        for ro in profile["read_only_roots"]:
            if path.begins_with(str(ro)):
                issues.append({"severity": "error", "kind": "permission_denied", "path": path,
                    "message": "Write to '%s' under %s: that root is read-only on this platform." % [path, profile_name],
                    "fix": "Write to user:// instead; res:// is packed read-only on mobile."})
    var joined := "/".join(segments)
    if joined.length() > int(profile["max_path"]):
        issues.append({"severity": "error", "kind": "too_long", "path": path,
            "message": "'%s' is %d chars; %s allows %d." % [path, joined.length(), profile_name, int(profile["max_path"])],
            "fix": "Shorten directory names near the leaf; long paths fail on Windows first."})
    for seg in segments:
        var s := str(seg)
        for ch in profile["forbidden"]:
            if ch in s:
                issues.append({"severity": "error", "kind": "forbidden_char", "path": path,
                    "message": "'%s' contains '%s', forbidden in file names on %s." % [s, ch, profile_name],
                    "fix": "Rename without platform-hostile characters."})
                break
        var upper := s.get_basename().to_upper()
        if upper in (profile["reserved"] as Array):
            issues.append({"severity": "error", "kind": "reserved_name", "path": path,
                "message": "'%s' is a reserved device name on %s - the export will fail or the file will be unreachable." % [s, profile_name],
                "fix": "Rename the file; Windows reserves these names regardless of extension."})
    if bool(profile["case_sensitive"]) and op == "read":
        var exact := false
        var ci_hit := ""
        var full := root + joined
        for f in files:
            if str(f) == full:
                exact = true
                break
            if str(f).to_lower() == full.to_lower():
                ci_hit = str(f)
        if not exact and ci_hit != "":
            issues.append({"severity": "error", "kind": "case_mismatch", "path": path,
                "message": "'%s' does not exist on %s, but '%s' does - case-sensitive platforms will 404 while Windows hides the bug." % [
                    path, profile_name, ci_hit],
                "fix": "Use the exact on-disk casing everywhere."})
    return issues


## Audit one script's text for platform-specific path literals.
func audit_script(text: String, path: String) -> Array:
    var issues: Array = []
    var re := RegEx.new()
    re.compile("\"([^\"]*(?:res:|user:)[^\"]*)\"")
    for m in re.search_all(text):
        var literal := m.get_string(1)
        if "\\" in literal:
            issues.append({"severity": "warning", "kind": "backslash_path", "path": path,
                "message": "%s: literal '%s' uses backslashes - POSIX platforms treat them as part of the name." % [path, literal],
                "fix": "Use forward slashes and String.path_join()."})
        if "/../" in literal:
            issues.append({"severity": "warning", "kind": "path_traversal", "path": path,
                "message": "%s: literal '%s' hardcodes a '..' climb." % [path, literal],
                "fix": "Build the path from a trusted root at runtime."})
    var re2 := RegEx.new()
    re2.compile("\"[A-Za-z]:\\\\\\\\")
    if re2.search(text) != null:
        issues.append({"severity": "warning", "kind": "drive_letter", "path": path,
            "message": "%s contains a Windows drive-letter path literal - dead on every other platform." % path,
            "fix": "Use res:// or user:// roots."})
    return issues


func collect_files() -> Array:
    var out: Array = []
    _walk("res://", out)
    return out


func _walk(dir_path: String, out: Array) -> void:
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
            if name != ".godot":
                _walk(full, out)
        else:
            out.append(full)
        name = dir.get_next()
    dir.list_dir_end()


func run(requests: Array = [], audit_scripts: bool = true) -> Dictionary:
    var issues: Array = []
    var files := collect_files()
    var checked := 0
    var by_lower: Dictionary = {}
    for f in files:
        var key := str(f).to_lower()
        if by_lower.has(key):
            issues.append({"severity": "error", "kind": "case_collision", "path": str(f),
                "message": "'%s' and '%s' differ only by case - case-insensitive exports (Windows, macOS) collapse them onto one file." % [str(by_lower[key]), str(f)],
                "fix": "Rename one of them; the collision survives export and one file silently wins."})
        else:
            by_lower[key] = f
    if requests.is_empty():
        # No explicit requests: self-check the real tree - every file
        # "read" under every profile catches case/reserved/length bugs.
        for f in files:
            for profile in PROFILES:
                checked += 1
                issues.append_array(resolve({"op": "read", "path": str(f)}, str(profile), files))
    else:
        for req in requests:
            for profile in PROFILES:
                checked += 1
                issues.append_array(resolve(req, str(profile), files))
    var scripts := 0
    if audit_scripts:
        for f in files:
            if str(f).get_extension() == "gd":
                scripts += 1
                issues.append_array(audit_script(FileAccess.get_file_as_string(str(f)), str(f)))
    var kinds: Dictionary = {}
    for i in issues:
        kinds[str(i["kind"])] = int(kinds.get(str(i["kind"]), 0)) + 1
    return {"summary": {"files": files.size(), "checks": checked, "scripts": scripts,
            "issues": issues.size()},
        "by_kind": kinds, "issues": issues}


func to_json(result: Dictionary) -> String:
    return JSON.stringify({"summary": result["summary"], "by_kind": result.get("by_kind", {}),
        "issues": result["issues"]}, "\t")


func to_markdown(result: Dictionary) -> String:
    var s: Dictionary = result["summary"]
    var lines: Array[String] = ["# Virtual Filesystem Report", "",
        "%d files, %d resolution checks across linux/windows/android/ios, %d scripts audited. %d violations." % [
            s["files"], s["checks"], s["scripts"], s["issues"]], ""]
    for i in result["issues"]:
        lines.append("- [%s] %s" % [i["severity"], i["message"]])
    return "\n".join(lines) + "\n"
