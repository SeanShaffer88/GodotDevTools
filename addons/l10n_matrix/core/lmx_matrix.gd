## Localization Matrix and In-Context Previewer - matrix operation.
## Reads the project's translation tables (Godot CSV format and PO) and
## builds the key x locale matrix: which keys are missing or empty in
## which locale, which translations grew so much over the source that
## they will overflow the box the source was laid out in, which keys the
## code never asks for (and which tr() calls no table answers), and -
## for PO files - whether the declared plural rule matches the built-in
## expectation for that locale. No machine translation and no network,
## per this project's rules: the "in-context" half is preview data
## (length, plural form, completeness per screen-facing key) that the
## dock renders next to the source string.
extends RefCounted

## A translation longer than source x this ratio is an overflow suspect.
var length_ratio: float = 1.6
## Expected plural rules per locale (nplurals), a small honest table.
const PLURAL_RULES: Dictionary = {"en": 2, "de": 2, "fr": 2, "es": 2, "it": 2,
    "pt": 2, "ja": 1, "ko": 1, "zh": 1, "pl": 3, "ru": 3, "cs": 3, "ar": 6}


func find_tables() -> Array:
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
        if name.begins_with(".") or name == "addons":
            name = dir.get_next()
            continue
        var full := dir_path.path_join(name)
        if dir.current_is_dir():
            if name != ".godot":
                _walk(full, out)
        elif name.get_extension().to_lower() in ["csv", "po"]:
            out.append(full)
        name = dir.get_next()
    dir.list_dir_end()


## Split one CSV line honouring double quotes.
func csv_line(line: String) -> Array:
    var cells: Array = []
    var current := ""
    var in_quotes := false
    var i := 0
    while i < line.length():
        var ch := line[i]
        if in_quotes:
            if ch == "\"":
                if i + 1 < line.length() and line[i + 1] == "\"":
                    current += "\""
                    i += 1
                else:
                    in_quotes = false
            else:
                current += ch
        elif ch == "\"":
            in_quotes = true
        elif ch == ",":
            cells.append(current)
            current = ""
        else:
            current += ch
        i += 1
    cells.append(current)
    return cells


## Parse a Godot translation CSV: header "keys,en,de,..." then rows.
func parse_csv(text: String) -> Dictionary:
    var lines := text.split("\n")
    if lines.is_empty():
        return {"locales": [], "entries": {}}
    var header := csv_line(lines[0].strip_edges().trim_prefix("\ufeff"))
    var locales: Array = []
    for i in range(1, header.size()):
        locales.append(str(header[i]).strip_edges())
    var entries: Dictionary = {}
    for n in range(1, lines.size()):
        var line := lines[n].strip_edges()
        if line == "":
            continue
        var cells := csv_line(line)
        if cells.is_empty() or str(cells[0]).strip_edges() == "":
            continue
        var key := str(cells[0]).strip_edges()
        var row: Dictionary = {}
        for i in locales.size():
            row[str(locales[i])] = str(cells[i + 1]).strip_edges() if i + 1 < cells.size() else ""
        entries[key] = row
    return {"locales": locales, "entries": entries}


## Parse a PO file into the same entry shape (one locale per file),
## plus its declared plural rule.
func parse_po(text: String) -> Dictionary:
    var locale := ""
    var nplurals := -1
    var entries: Dictionary = {}
    var msgid := ""
    var mode := ""
    for raw in text.split("\n"):
        var line := raw.strip_edges()
        if line.begins_with("\"Language:") and msgid == "":
            locale = line.trim_prefix("\"Language:").trim_suffix("\\n\"").strip_edges()
        if line.contains("Plural-Forms:") and line.contains("nplurals="):
            var part := line.substr(line.find("nplurals=") + 9)
            var digits := ""
            for ch in part:
                if ch >= "0" and ch <= "9":
                    digits += ch
                else:
                    break
            if digits != "":
                nplurals = int(digits)
        if line.begins_with("msgid "):
            msgid = _unquote(line.trim_prefix("msgid "))
            mode = "id"
        elif line.begins_with("msgstr "):
            if msgid != "":
                entries[msgid] = _unquote(line.trim_prefix("msgstr "))
            mode = "str"
        elif line.begins_with("\"") and mode != "":
            if mode == "id":
                msgid += _unquote(line)
            elif entries.has(msgid):
                entries[msgid] = str(entries[msgid]) + _unquote(line)
    return {"locales": [locale] if locale != "" else [], "entries": entries,
        "nplurals": nplurals, "locale": locale}


func _unquote(s: String) -> String:
    var t := s.strip_edges()
    if t.begins_with("\"") and t.ends_with("\"") and t.length() >= 2:
        t = t.substr(1, t.length() - 2)
    return t.replace("\\n", "\n").replace("\\\"", "\"")


## Scan project sources for tr("key") usage.
func find_used_keys() -> Dictionary:
    var used: Dictionary = {}
    var re := RegEx.new()
    re.compile("tr\\(\\s*\"([^\"]+)\"")
    _scan_dir("res://", re, used)
    return used


func _scan_dir(dir_path: String, re: RegEx, used: Dictionary) -> void:
    var dir := DirAccess.open(dir_path)
    if dir == null:
        return
    dir.list_dir_begin()
    var name := dir.get_next()
    while name != "":
        if name.begins_with(".") or name == "addons":
            name = dir.get_next()
            continue
        var full := dir_path.path_join(name)
        if dir.current_is_dir():
            if name != ".godot":
                _scan_dir(full, re, used)
        elif name.get_extension() in ["gd", "tscn"]:
            var text := FileAccess.get_file_as_string(full)
            for m in re.search_all(text):
                used[m.get_string(1)] = str(full)
        name = dir.get_next()
    dir.list_dir_end()


## The one operation: merge every table found (or the ones given) into
## one matrix and report the problems.
func run(tables: Dictionary = {}) -> Dictionary:
    var issues: Array = []
    var locales: Array = []
    var entries: Dictionary = {}
    var po_rules: Dictionary = {}
    if tables.is_empty():
        for path in find_tables():
            var text := FileAccess.get_file_as_string(str(path))
            if str(path).get_extension().to_lower() == "po":
                var po := parse_po(text)
                for loc in po["locales"]:
                    if loc not in locales:
                        locales.append(loc)
                if int(po.get("nplurals", -1)) >= 0 and str(po.get("locale", "")) != "":
                    po_rules[str(po["locale"])] = int(po["nplurals"])
                for key in po["entries"]:
                    if not entries.has(key):
                        entries[key] = {}
                    for loc in po["locales"]:
                        (entries[key] as Dictionary)[str(loc)] = po["entries"][key]
            else:
                var csv := parse_csv(text)
                for loc in csv["locales"]:
                    if str(loc) not in locales:
                        locales.append(str(loc))
                for key in csv["entries"]:
                    if not entries.has(key):
                        entries[key] = {}
                    (entries[key] as Dictionary).merge(csv["entries"][key], true)
    else:
        entries = tables.get("entries", {})
        locales = tables.get("locales", [])
        po_rules = tables.get("po_rules", {})
    for loc in po_rules:
        if PLURAL_RULES.has(loc) and int(po_rules[loc]) != int(PLURAL_RULES[loc]):
            issues.append({"severity": "warning", "kind": "plural_mismatch", "path": str(loc),
                "message": "The PO for '%s' declares nplurals=%d, but '%s' needs %d plural forms." % [
                    loc, int(po_rules[loc]), loc, int(PLURAL_RULES[loc])],
                "fix": "Correct the Plural-Forms header; wrong plural counts silently pick the wrong form at runtime."})
    var used := find_used_keys()
    var source_locale := "en" if "en" in locales else (str(locales[0]) if not locales.is_empty() else "en")
    for key in entries:
        var row: Dictionary = entries[key]
        for loc in locales:
            var value := str(row.get(str(loc), ""))
            if value == "":
                issues.append({"severity": "error", "kind": "missing_translation", "path": str(key),
                    "message": "Key '%s' has no '%s' translation." % [key, loc],
                    "fix": "Fill the cell in the translation table; empty cells fall back to the key text on screen."})
                continue
            var source := str(row.get(source_locale, ""))
            if loc != source_locale and source != "" and float(value.length()) > float(source.length()) * length_ratio:
                issues.append({"severity": "warning", "kind": "length_risk", "path": str(key),
                    "message": "'%s' in '%s' is %d chars vs %d in the source - boxes laid out for the source will overflow." % [
                        key, loc, value.length(), source.length()],
                    "fix": "Shorten the translation, or give the control autowrap/autoshrink and test it in the Responsive UI Previewer."})
        if not used.has(str(key)):
            issues.append({"severity": "info", "kind": "unused_key", "path": str(key),
                "message": "Key '%s' is in the table but no tr() call in the project uses it." % [key],
                "fix": "Delete it if the text is gone, or check the key is not built at runtime from pieces (this scan sees written tr() calls only)."})
    for key in used:
        if not entries.has(str(key)):
            issues.append({"severity": "error", "kind": "untranslated_call", "path": str(used[key]),
                "message": "tr(\"%s\") is called in %s but no table has that key - players see the raw key." % [key, used[key]],
                "fix": "Add the key to the translation table, or fix the spelling in the tr() call."})
    var missing := 0
    for i in issues:
        if str(i["kind"]) == "missing_translation":
            missing += 1
    return {"summary": {"keys": entries.size(), "locales": locales.size(),
            "missing": missing, "issues": issues.size()},
        "matrix": entries, "locales": locales, "issues": issues}


func to_json(result: Dictionary) -> String:
    return JSON.stringify({"summary": result["summary"], "issues": result["issues"],
        "locales": result["locales"]}, "\t")


func to_markdown(result: Dictionary) -> String:
    var s: Dictionary = result["summary"]
    var lines: Array[String] = ["# Localization Matrix Report", "",
        "%d keys across %d locale(s): %d missing translations, %d findings total." % [
            s["keys"], s["locales"], s["missing"], s["issues"]], ""]
    for i in result["issues"]:
        lines.append("- [%s] %s" % [i["severity"], i["message"]])
    return "\n".join(lines) + "\n"
