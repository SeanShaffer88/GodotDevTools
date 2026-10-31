## Human review metadata only; never modifies screenshots or approves baselines.
extends RefCounted

## Build a detached queue from a suite result. Image content is identified by SHA-256.
func build(suite: Dictionary, baseline_dir: String, current_dir: String) -> Dictionary:
    var items: Array = []
    for comparison in suite.get("comparisons", []):
        var verdict := str(comparison.get("verdict", ""))
        if verdict == "pass":
            continue
        var name := str(comparison.get("name", ""))
        if not _safe_name(name):
            continue
        var baseline := baseline_dir.path_join(name)
        var capture := current_dir.path_join(name)
        var capture_hash := FileAccess.get_sha256(capture) if FileAccess.file_exists(capture) else ""
        var baseline_hash := FileAccess.get_sha256(baseline) if FileAccess.file_exists(baseline) else ""
        var actionable := verdict in ["fail", "missing_baseline"] and not capture_hash.is_empty() and (verdict == "missing_baseline" or not baseline_hash.is_empty())
        items.append({"name": name, "verdict": verdict, "baseline": baseline, "capture": capture,
            "baseline_sha256": baseline_hash, "capture_sha256": capture_hash,
            "status": "pending" if actionable else "blocked", "history": []})
    items.sort_custom(func(a, b): return str(a["name"]) < str(b["name"]))
    return {"version": 1, "items": items}

## Record a decision on a detached copy after verifying the files still match.
## timestamp is supplied by the caller for deterministic tests and transparent history.
func decide(queue: Dictionary, name: String, decision: String, reviewer: String, note: String, timestamp: String) -> Dictionary:
    if not _safe_name(name) or decision not in ["approved", "rejected"] or reviewer.strip_edges().is_empty() or timestamp.strip_edges().is_empty():
        return {"ok": false, "error": "A safe PNG name, approved/rejected decision, reviewer and timestamp are required."}
    if int(queue.get("version", 0)) != 1 or typeof(queue.get("items")) != TYPE_ARRAY:
        return {"ok": false, "error": "Invalid review queue format."}
    var output: Dictionary = queue.duplicate(true)
    var selected: Dictionary = {}
    var matches := 0
    for item in output["items"]:
        if typeof(item) != TYPE_DICTIONARY:
            return {"ok": false, "error": "Invalid queue item."}
        if str(item.get("name", "")) == name:
            selected = item
            matches += 1
    if matches != 1:
        return {"ok": false, "error": "Expected exactly one matching queue item."}
    if str(selected.get("status", "")) not in ["pending", "approved", "rejected"] or str(selected.get("verdict", "")) not in ["fail", "missing_baseline"] or typeof(selected.get("history")) != TYPE_ARRAY:
        return {"ok": false, "error": "Item is blocked or has invalid status, verdict or history."}
    var capture := str(selected.get("capture", ""))
    var baseline := str(selected.get("baseline", ""))
    if capture.get_file() != name or baseline.get_file() != name:
        return {"ok": false, "error": "Queue paths do not match the item name."}
    var expected_capture := str(selected.get("capture_sha256", ""))
    var expected_baseline := str(selected.get("baseline_sha256", ""))
    if expected_capture.is_empty() or not FileAccess.file_exists(capture) or FileAccess.get_sha256(capture) != expected_capture:
        return {"ok": false, "error": "Capture is missing or changed since the queue was generated."}
    var baseline_exists := FileAccess.file_exists(baseline)
    if (str(selected["verdict"]) == "missing_baseline" and (baseline_exists or not expected_baseline.is_empty())) or (str(selected["verdict"]) == "fail" and (not baseline_exists or expected_baseline.is_empty())):
        return {"ok": false, "error": "Baseline presence does not match the reviewed item."}
    var actual_baseline := FileAccess.get_sha256(baseline) if baseline_exists else ""
    if actual_baseline != expected_baseline:
        return {"ok": false, "error": "Baseline changed since the queue was generated."}
    selected["status"] = decision
    selected["history"].append({"decision": decision, "reviewer": reviewer, "note": note, "timestamp": timestamp,
        "capture_sha256": expected_capture, "baseline_sha256": expected_baseline})
    return {"ok": true, "queue": output}

func _safe_name(name: String) -> bool:
    return not name.is_empty() and name == name.get_file() and name.get_extension().to_lower() == "png" and not name.contains("\\")
