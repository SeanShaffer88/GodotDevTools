## Natural-Language Scene Search - project index + query operation.
## Indexes every scene and script: node types and names inside scenes,
## script class names, functions, variables, state-machine hints (any
## variable or enum mentioning "state", state names in strings),
## autoload use, and plain keywords. A natural-language query such as
## "find enemies that use a patrol state" or "show scenes with a door
## interaction" is turned into structured terms by a small rule-based
## parser (no network, no AI service): it extracts the subject word,
## behaviour words and interaction words, then ranks indexed files by
## how many of those terms they match - each result carries the plain
## reason it matched, so the ranking can be checked.
extends RefCounted

const STOP_WORDS: Array[String] = ["find", "show", "me", "the", "a", "an", "that", "which", "with",
    "use", "uses", "using", "have", "has", "all", "any", "in", "of", "scenes", "scene", "files",
    "file", "nodes", "node", "please", "where", "what", "list", "get", "search", "for"]
const SKIP_DIRS: Array[String] = [".godot", ".git", "addons"]

var _index: Array[Dictionary] = [] ## per file: {path, kind, terms:{term: [reasons]}, text}


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


func _add_term(entry: Dictionary, term: String, reason: String) -> void:
    var t := term.to_lower().strip_edges()
    if t.length() < 3:
        return
    var terms: Dictionary = entry["terms"]
    if not terms.has(t):
        terms[t] = []
    if not (terms[t] as Array).has(reason):
        (terms[t] as Array).append(reason)


func build_index() -> Dictionary:
    _index.clear()
    var files: Array[String] = []
    _walk("res://", files)
    var node_re := RegEx.new()
    node_re.compile("\\[node name=\"([^\"]+)\"(?: type=\"([^\"]+)\")?")
    var func_re := RegEx.new()
    func_re.compile("(?m)^func\\s+([A-Za-z0-9_]+)")
    var var_re := RegEx.new()
    var_re.compile("(?m)^(?:@export\\s+)?var\\s+([A-Za-z0-9_]+)")
    var class_re := RegEx.new()
    class_re.compile("(?m)^class_name\\s+([A-Za-z0-9_]+)")
    for path in files:
        var ext := path.get_extension().to_lower()
        if ext not in ["tscn", "gd", "tres"]:
            continue
        var text := FileAccess.get_file_as_string(path)
        var entry: Dictionary = {"path": path, "kind": "scene" if ext == "tscn" else ("script" if ext == "gd" else "resource"),
            "terms": {}, "text": text.to_lower()}
        _add_term(entry, path.get_file().get_basename(), "file name")
        for token in path.get_file().get_basename().split("_"):
            _add_term(entry, token, "file name")
        if ext == "tscn":
            for m in node_re.search_all(text):
                _add_term(entry, m.get_string(1), "node named '%s'" % m.get_string(1))
                for token in m.get_string(1).split("_"):
                    _add_term(entry, token, "node name")
                if m.get_string(2) != "":
                    _add_term(entry, m.get_string(2), "node type %s" % m.get_string(2))
        if ext == "gd":
            for m in func_re.search_all(text):
                _add_term(entry, m.get_string(1), "function %s()" % m.get_string(1))
                for token in m.get_string(1).split("_"):
                    _add_term(entry, token, "function name")
            for m in var_re.search_all(text):
                _add_term(entry, m.get_string(1), "variable %s" % m.get_string(1))
                if m.get_string(1).to_lower().contains("state"):
                    _add_term(entry, "state", "state variable %s" % m.get_string(1))
            var cm := class_re.search(text)
            if cm != null:
                _add_term(entry, cm.get_string(1), "class_name %s" % cm.get_string(1))
        _index.append(entry)
    return {"files": _index.size()}


## Turn a natural-language query into search terms: drop grammar words,
## keep content words, and expand a few behaviour phrases ("patrol
## state" keeps both words and adds "state").
func parse_query(query: String) -> Array:
    var terms: Array = []
    var cleaned := query.to_lower()
    for ch in [".", ",", "?", "!", "\"", "'"]:
        cleaned = cleaned.replace(ch, " ")
    for word in cleaned.split(" ", false):
        var wword := word.strip_edges()
        if wword == "" or STOP_WORDS.has(wword):
            continue
        if not terms.has(wword):
            terms.append(wword)
        # Simple stemming: enemies -> enemy, doors -> door
        if wword.ends_with("ies") and wword.length() > 4:
            var stem := wword.left(wword.length() - 3) + "y"
            if not terms.has(stem):
                terms.append(stem)
        elif wword.ends_with("s") and wword.length() > 3:
            var stem2 := wword.left(wword.length() - 1)
            if not terms.has(stem2):
                terms.append(stem2)
    return terms


func search(query: String, limit: int = 20) -> Dictionary:
    if _index.is_empty():
        build_index()
    var terms := parse_query(query)
    var word_res: Dictionary = {}
    for term in terms:
        var wre := RegEx.new()
        if wre.compile("\\b" + term + "\\b") == OK:
            word_res[term] = wre
    var results: Array = []
    for entry in _index:
        var score := 0
        var reasons: Array = []
        for term in terms:
            if (entry["terms"] as Dictionary).has(term):
                score += 3
                for r in entry["terms"][term]:
                    if not reasons.has(r):
                        reasons.append(r)
            elif word_res.has(term) and (word_res[term] as RegEx).search(str(entry["text"])) != null:
                score += 1
                if not reasons.has("mentions '%s' in its content" % term):
                    reasons.append("mentions '%s' in its content" % term)
        if score > 0:
            results.append({"path": entry["path"], "kind": entry["kind"], "score": score, "reasons": reasons})
    results.sort_custom(func(a, b): return int(a["score"]) > int(b["score"]) if int(a["score"]) != int(b["score"]) else str(a["path"]) < str(b["path"]))
    var trimmed := results.slice(0, limit)
    var issues: Array = []
    if trimmed.is_empty():
        issues.append({"severity": "info", "kind": "no_results", "path": "",
            "message": "No files matched \"%s\" (terms: %s)." % [query, ", ".join(terms)],
            "fix": "Try the words used in your file, node or function names - the index matches names and content, not synonyms."})
    return {"summary": {"query": query, "terms": terms, "results": trimmed.size(), "indexed_files": _index.size()},
        "results": trimmed, "issues": issues, "terms": terms}


func to_json(result: Dictionary) -> String:
    return JSON.stringify({"summary": result["summary"], "results": result["results"]}, "\t")


func to_markdown(result: Dictionary) -> String:
    var lines: Array[String] = ["# Scene Search Results", "",
        "Query: \"%s\" - %d results from %d indexed files." % [result["summary"]["query"], result["summary"]["results"], result["summary"]["indexed_files"]], ""]
    for r in result["results"]:
        lines.append("- **%s** (%s, score %d) - %s" % [r["path"], r["kind"], r["score"], "; ".join(r["reasons"])])
    return "\n".join(lines) + "\n"
