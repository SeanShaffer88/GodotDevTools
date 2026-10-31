## Camera Shake, Transition and Framing Orchestrator - motion maths.
## The pure half of the orchestrator: a seeded value-noise shake (the
## same seed always produces the same shake, so a bug can be replayed),
## deadzone framing maths (a target inside the deadzone moves the camera
## not at all; outside it, the camera follows to the nearest edge), and
## keyframed transitions sampled with real ease curves. run() validates
## a shake/transition/framing config and pre-computes the samples the
## dock's preview draws. The runtime node (runtime/cor_camera.gd)
## applies these same functions to a live Camera2D each frame - this file
## never touches a node, so every curve here is testable headless.
extends RefCounted

## Hand-rolled 32-bit LCG: deterministic on every platform, unlike
## relying on float noise or randf() state.
func seeded_value(seed_value: int, index: int) -> float:
    var h := (seed_value * 1103515245 + 12345 + index * 2246822519) & 0x7FFFFFFF
    h = (h ^ (h >> 13)) * 1274126177
    h = h & 0x7FFFFFFF
    return float(h) / float(0x7FFFFFFF) * 2.0 - 1.0


## Shake offset at time t (seconds): value noise between seeded points
## at `frequency` Hz, amplitude decaying exponentially over `duration`.
func shake_sample(config: Dictionary, t: float) -> Vector2:
    var amplitude := float(config.get("amplitude", 8.0))
    var frequency := maxf(float(config.get("frequency", 24.0)), 0.1)
    var duration := maxf(float(config.get("duration", 0.4)), 0.001)
    var seed_value := int(config.get("seed", 1))
    if t >= duration:
        return Vector2.ZERO
    var decay := 1.0 - (t / duration)
    decay = decay * decay
    var phase := t * frequency
    var i := int(floorf(phase))
    var f := phase - float(i)
    var smooth := f * f * (3.0 - 2.0 * f)
    var nx := lerpf(seeded_value(seed_value, i), seeded_value(seed_value, i + 1), smooth)
    var ny := lerpf(seeded_value(seed_value, i + 7919), seeded_value(seed_value, i + 7920), smooth)
    return Vector2(nx, ny) * amplitude * decay


func ease_value(ease_name: String, t: float) -> float:
    var x := clampf(t, 0.0, 1.0)
    match ease_name:
        "linear":
            return x
        "in_quad":
            return x * x
        "out_quad":
            return 1.0 - (1.0 - x) * (1.0 - x)
        "in_out_cubic":
            return 4.0 * x * x * x if x < 0.5 else 1.0 - pow(-2.0 * x + 2.0, 3.0) / 2.0
        "out_back":
            var c := 1.70158 + 1.0
            return 1.0 + c * pow(x - 1.0, 3.0) + 1.70158 * pow(x - 1.0, 2.0)
        "out_elastic":
            if x == 0.0 or x == 1.0:
                return x
            return pow(2.0, -10.0 * x) * sin((x * 10.0 - 0.75) * (TAU / 3.0)) + 1.0
    return x


const EASES: Array[String] = ["linear", "in_quad", "out_quad", "in_out_cubic", "out_back", "out_elastic"]


## Transition value at time t: from -> to over duration on the named
## ease curve.
func transition_sample(config: Dictionary, t: float) -> float:
    var duration := maxf(float(config.get("duration", 1.0)), 0.001)
    var from := float(config.get("from", 0.0))
    var to := float(config.get("to", 1.0))
    var ease_name := str(config.get("ease", "linear"))
    if ease_name not in EASES:
        ease_name = "linear"
    return lerpf(from, to, ease_value(ease_name, t / duration))


## Deadzone framing: camera position that keeps `target` inside the
## deadzone rect centred on the camera, moving as little as possible.
func framing_position(camera: Vector2, target: Vector2, deadzone: Vector2) -> Vector2:
    var half := deadzone * 0.5
    var pos := camera
    if target.x < camera.x - half.x:
        pos.x = target.x + half.x
    elif target.x > camera.x + half.x:
        pos.x = target.x - half.x
    if target.y < camera.y - half.y:
        pos.y = target.y + half.y
    elif target.y > camera.y + half.y:
        pos.y = target.y - half.y
    return pos


## The one operation: validate a config and pre-compute preview samples.
func run(config: Dictionary) -> Dictionary:
    var issues: Array = []
    for shake in config.get("shakes", []):
        var s: Dictionary = shake
        if float(s.get("amplitude", 1.0)) < 0.0:
            issues.append({"severity": "error", "kind": "config_error", "path": str(s.get("name", "shake")),
                "message": "Shake '%s' has a negative amplitude." % s.get("name", "shake"),
                "fix": "Amplitude is a magnitude in pixels; make it positive."})
        if float(s.get("duration", 1.0)) <= 0.0:
            issues.append({"severity": "error", "kind": "config_error", "path": str(s.get("name", "shake")),
                "message": "Shake '%s' has duration %s - a shake that never plays or plays forever." % [s.get("name", "shake"), s.get("duration")],
                "fix": "Give it a positive duration in seconds (0.2-0.6 reads as an impact)."})
        if float(s.get("frequency", 1.0)) <= 0.0:
            issues.append({"severity": "error", "kind": "config_error", "path": str(s.get("name", "shake")),
                "message": "Shake '%s' has a non-positive frequency." % s.get("name", "shake"),
                "fix": "Frequency is noise points per second; try 15-30 for impacts."})
    for tr in config.get("transitions", []):
        var t: Dictionary = tr
        var ease_name := str(t.get("ease", "linear"))
        if ease_name not in EASES:
            issues.append({"severity": "warning", "kind": "config_error", "path": str(t.get("name", "transition")),
                "message": "Transition '%s' names ease '%s'; known eases are %s. Falling back to linear." % [
                    t.get("name", "transition"), ease_name, ", ".join(EASES)],
                "fix": "Pick one of the listed ease names."})
        if float(t.get("duration", 1.0)) <= 0.0:
            issues.append({"severity": "error", "kind": "config_error", "path": str(t.get("name", "transition")),
                "message": "Transition '%s' has duration %s." % [t.get("name", "transition"), t.get("duration")],
                "fix": "Give it a positive duration in seconds."})
    var framing: Dictionary = config.get("framing", {})
    if not framing.is_empty():
        var dz: Array = framing.get("deadzone", [0, 0])
        if dz.size() != 2 or float(dz[0]) <= 0.0 or float(dz[1]) <= 0.0:
            issues.append({"severity": "error", "kind": "config_error", "path": "framing",
                "message": "Framing deadzone must be [width, height] with both positive.",
                "fix": "A deadzone of e.g. [120, 80] pixels keeps small movement from dragging the camera."})
    var previews: Dictionary = {}
    var samples := int(config.get("preview_samples", 40))
    for shake in config.get("shakes", []):
        var s: Dictionary = shake
        var pts: Array = []
        var duration := maxf(float(s.get("duration", 0.4)), 0.001)
        for i in samples:
            var t := duration * float(i) / float(maxi(samples - 1, 1))
            var offset := shake_sample(s, t)
            pts.append({"t": t, "x": offset.x, "y": offset.y})
        previews["shake:" + str(s.get("name", "shake"))] = pts
    for tr in config.get("transitions", []):
        var t2: Dictionary = tr
        var pts2: Array = []
        var duration2 := maxf(float(t2.get("duration", 1.0)), 0.001)
        for i in samples:
            var t := duration2 * float(i) / float(maxi(samples - 1, 1))
            pts2.append({"t": t, "value": transition_sample(t2, t)})
        previews["transition:" + str(t2.get("name", "transition"))] = pts2
    return {"summary": {"shakes": config.get("shakes", []).size(),
            "transitions": config.get("transitions", []).size(),
            "framing": not framing.is_empty(), "issues": issues.size()},
        "previews": previews, "issues": issues}


func to_json(result: Dictionary) -> String:
    return JSON.stringify({"summary": result["summary"], "issues": result["issues"]}, "\t")


func to_markdown(result: Dictionary) -> String:
    var s: Dictionary = result["summary"]
    var lines: Array[String] = ["# Camera Orchestrator Report", "",
        "%d shake(s), %d transition(s), framing %s. %d problems." % [
            s["shakes"], s["transitions"], "on" if s["framing"] else "off", s["issues"]], ""]
    for i in result["issues"]:
        lines.append("- [%s] %s" % [i["severity"], i["message"]])
    return "\n".join(lines) + "\n"
