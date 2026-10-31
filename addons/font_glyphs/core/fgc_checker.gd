## Font Glyph Coverage Checker - cmap coverage.
## Parses the font's cmap table (format 4 BMP and format 12 full Unicode
## subtables) to get the code points it maps, collects every character used
## by each locale column of translation CSVs (and msgstr text of .po files),
## and lists characters each locale needs that the font lacks. Control
## characters are ignored. Fallback fonts are not considered.
extends RefCounted

const EXTS: Array[String] = ["csv", "po"]
const DEFAULTS := {"strings": "res://"}


func run(input: String = "", options: Dictionary = {}) -> Dictionary:
    var opts := _opts(options)
    if not FileAccess.file_exists(input):
        return _fail(input, "Font file not found.", "Pass --font=<path to .ttf/.otf>.", "bad_font")
    var covered := cmap(FileAccess.get_file_as_bytes(input))
    if covered.is_empty():
        return _fail(input, "No readable cmap table (TrueType/OpenType only; collections and WOFF are not supported).", "Point at a .ttf or .otf file.", "bad_font")
    var dir := str(opts["strings"])
    if DirAccess.open(dir) == null:
        return _fail(dir, "Cannot open strings folder.", "Pass --strings=<folder>.")
    var paths: Array = []
    _walk(dir, paths)
    paths.sort()
    var texts := {}
    for path in paths:
        texts[path] = FileAccess.get_file_as_string(path)
    var result := analyze(texts, {"covered": covered, "font": input})
    return result


## Returns {codepoint: true} for every character the font maps to a glyph.
func cmap(b: PackedByteArray) -> Dictionary:
    var out := {}
    if b.size() < 12:
        return out
    var num_tables := _u16(b, 4)
    var cmap_off := -1
    for i in range(num_tables):
        var rec := 12 + i * 16
        if rec + 16 > b.size():
            return out
        if b.slice(rec, rec + 4).get_string_from_ascii() == "cmap":
            cmap_off = _u32(b, rec + 8)
    if cmap_off < 0 or cmap_off + 4 > b.size():
        return out
    var subtables := _u16(b, cmap_off + 2)
    var best := -1
    var best_rank := -1
    for i in range(subtables):
        var r := cmap_off + 4 + i * 8
        var platform := _u16(b, r)
        var encoding := _u16(b, r + 2)
        var off := cmap_off + _u32(b, r + 4)
        if off + 2 > b.size():
            continue
        var fmt := _u16(b, off)
        var rank := -1
        if fmt == 12 and (platform == 3 and encoding == 10 or platform == 0):
            rank = 2
        elif fmt == 4 and (platform == 3 and encoding == 1 or platform == 0):
            rank = 1
        if rank > best_rank:
            best_rank = rank
            best = off
    if best < 0:
        return out
    if _u16(b, best) == 12:
        var groups := _u32(b, best + 12)
        for g in range(groups):
            var o := best + 16 + g * 12
            var start := _u32(b, o)
            var end := _u32(b, o + 4)
            for c in range(start, min(end, start + 0x10000) + 1):
                out[c] = true
    else:
        var seg2 := _u16(b, best + 6)
        var ends := best + 14
        var starts := ends + seg2 + 2
        var deltas := starts + seg2
        var ranges := deltas + seg2
        for s in range(seg2 / 2):
            var end := _u16(b, ends + s * 2)
            var start := _u16(b, starts + s * 2)
            var delta := _u16(b, deltas + s * 2)
            var range_off := _u16(b, ranges + s * 2)
            for c in range(start, end + 1):
                if c == 0xFFFF:
                    continue
                var glyph := 0
                if range_off == 0:
                    glyph = (c + delta) & 0xFFFF
                else:
                    var addr := ranges + s * 2 + range_off + (c - start) * 2
                    if addr + 2 <= b.size():
                        glyph = _u16(b, addr)
                        if glyph != 0:
                            glyph = (glyph + delta) & 0xFFFF
                if glyph != 0:
                    out[c] = true
    return out


func _u16(b: PackedByteArray, o: int) -> int:
    return (b[o] << 8) | b[o + 1]


func _u32(b: PackedByteArray, o: int) -> int:
    return (b[o] << 24) | (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3]


## texts: translation files; options.covered: {codepoint: true}.
func analyze(texts: Dictionary, options: Dictionary = {}) -> Dictionary:
    var covered: Dictionary = options.get("covered", {})
    var font: String = options.get("font", "")
    var issues: Array = []
    var needed := {}  # locale -> {codepoint: true}
    for path in texts.keys():
        if texts[path] == null:
            issues.append(_issue("error", "scan_error", str(path), 0, "Cannot read file.", "Check file permissions and retry."))
            continue
        var text := str(texts[path])
        if str(path).get_extension() == "po":
            var locale := str(path).get_file().get_basename()
            for line in text.split("\n"):
                if line.begins_with("msgstr"):
                    _collect(needed, locale, line.get_slice("\"", 1))
        else:
            var rows := text.split("\n", false)
            if rows.size() < 2:
                continue
            var header := _csv(rows[0])
            if header.size() < 2:
                continue
            for r in range(1, rows.size()):
                var cells := _csv(rows[r])
                for c in range(1, min(cells.size(), header.size())):
                    _collect(needed, header[c], cells[c])
    var report := {}
    var locales: Array = needed.keys()
    locales.sort()
    for locale in locales:
        var missing: Array = []
        for cp in needed[locale].keys():
            if not covered.has(cp):
                missing.append(cp)
        missing.sort()
        report[locale] = {"used": needed[locale].size(), "missing": missing.size()}
        if not missing.is_empty():
            var shown: Array = []
            for cp in missing.slice(0, 20):
                shown.append("%s (U+%04X)" % [String.chr(cp), cp])
            issues.append(_issue("warning", "missing_glyphs", font, 0, "Locale %s uses %d characters the font lacks: %s%s." % [locale, missing.size(), ", ".join(shown), " ..." if missing.size() > 20 else ""], "Use a font that covers this locale, or add a fallback font for it in the theme/FontFile."))
    return _finish({"font_codepoints": covered.size(), "locales": report.size()}, issues, {"locales": report})


func _collect(needed: Dictionary, locale: String, text: String) -> void:
    if not needed.has(locale):
        needed[locale] = {}
    for ch in text:
        var cp := ch.unicode_at(0)
        if cp >= 0x20 and cp != 0x7F:
            needed[locale][cp] = true


func _csv(line: String) -> PackedStringArray:
    var out := PackedStringArray()
    var cur := ""
    var quoted := false
    var i := 0
    while i < line.length():
        var c := line[i]
        if c == "\"":
            if quoted and i + 1 < line.length() and line[i + 1] == "\"":
                cur += "\""
                i += 1
            else:
                quoted = not quoted
        elif c == "," and not quoted:
            out.append(cur)
            cur = ""
        else:
            cur += c
        i += 1
    out.append(cur.strip_edges(false, true))
    return out


func _walk(path: String, out: Array) -> void:
    var dir := DirAccess.open(path)
    if dir == null:
        return
    dir.list_dir_begin()
    var name := dir.get_next()
    while name != "":
        if not name.begins_with(".") and name not in ["addons", "reports", "visual_reports"]:
            var child := path.path_join(name)
            if dir.current_is_dir():
                _walk(child, out)
            elif name.get_extension().to_lower() in EXTS:
                out.append(child)
        name = dir.get_next()
    dir.list_dir_end()


func _opts(options: Dictionary) -> Dictionary:
    var merged: Dictionary = DEFAULTS.duplicate(true)
    merged.merge(options, true)
    return merged


func _read_json(path: String) -> Variant:
    if not FileAccess.file_exists(path):
        return null
    return JSON.parse_string(FileAccess.get_file_as_string(path))


func _issue(severity: String, kind: String, path: String, line: int, message: String, fix: String) -> Dictionary:
    return {"severity": severity, "kind": kind, "path": path, "line": line, "message": message, "fix": fix}


func _fail(path: String, message: String, fix: String, kind: String = "scan_error") -> Dictionary:
    return {"summary": {"issues": 1}, "issues": [_issue("error", kind, path, 0, message, fix)]}


func _finish(summary: Dictionary, issues: Array, extra: Dictionary = {}) -> Dictionary:
    issues.sort_custom(func(a, b): return "%s|%08d|%s" % [a["path"], int(a["line"]), a["kind"]] < "%s|%08d|%s" % [b["path"], int(b["line"]), b["kind"]])
    summary["issues"] = issues.size()
    var result := {"summary": summary, "issues": issues}
    result.merge(extra)
    return result


func _count(result: Dictionary, kind: String) -> int:
    var n := 0
    for issue in result["issues"]:
        if issue["kind"] == kind:
            n += 1
    return n


func to_json(result: Dictionary) -> String:
    return JSON.stringify(result, "  ")


func to_markdown(result: Dictionary) -> String:
    var lines: Array = ["# Font Glyph Coverage Checker", "", "Summary: " + str(result["summary"]), ""]
    if has_method("_markdown_extra"):
        lines.append_array(call("_markdown_extra", result))
    lines.append("## Findings")
    for issue in result["issues"]:
        lines.append("- **%s** `%s:%s`: %s %s" % [issue["kind"], issue["path"], issue["line"], issue["message"], issue["fix"]])
    return "\n".join(lines) + "\n"
