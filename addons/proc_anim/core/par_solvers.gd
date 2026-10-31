## Procedural Animation Rigging Helper - solver operation.
## The maths behind the toolkit, pure and headless: an analytic two-bone
## IK solver, a FABRIK chain solver, a look-at angle, volume-preserving
## squash-and-stretch keyframes, and a foot-placement probe against a
## sampled ground line. run() validates a rig config JSON by solving
## every chain in it and reporting which ones cannot reach their target
## or converge - the config check that keeps a rig honest before it is
## wired to bones. The runtime node (runtime/par_rig.gd) applies these
## same solvers to real bones in a live scene.
extends RefCounted

var default_iterations: int = 16
var default_tolerance: float = 0.5


## Analytic two-bone IK in 2D. Returns the joint position, the end
## position, whether the target was reachable, and the residual error.
func solve_two_bone(root: Vector2, target: Vector2, l1: float, l2: float, bend_sign: int = 1) -> Dictionary:
    var to_target := target - root
    var d := to_target.length()
    var reach := l1 + l2
    var min_reach := absf(l1 - l2)
    var reachable := d <= reach and d >= min_reach
    var clamped := clampf(d, maxf(min_reach, 0.0001), maxf(reach, 0.0002))
    var base_dir := to_target.normalized() if d > 0.0001 else Vector2.RIGHT
    var cos_a := clampf((l1 * l1 + clamped * clamped - l2 * l2) / maxf(2.0 * l1 * clamped, 0.000001), -1.0, 1.0)
    var bone_dir := base_dir.rotated(float(bend_sign) * acos(cos_a))
    var joint := root + bone_dir * l1
    var clamped_point := root + base_dir * clamped
    var to_end := clamped_point - joint
    var end := joint + (to_end.normalized() * l2 if to_end.length() > 0.0001 else bone_dir * l2)
    return {"joint": joint, "end": end, "reachable": reachable,
        "error": end.distance_to(target), "base_angle": base_dir.angle()}


## FABRIK over a 2D point chain: forward reach to the target, backward
## anchor to the root, until the end is within tolerance or the
## iteration budget runs out. Deterministic: same input, same output.
func fabrik(points: Array, target: Vector2, iterations: int = -1, tolerance: float = -1.0) -> Dictionary:
    var pts: Array = points.duplicate()
    var tol := tolerance if tolerance >= 0.0 else default_tolerance
    var its := iterations if iterations > 0 else default_iterations
    var lengths: Array = []
    var total := 0.0
    for i in range(1, pts.size()):
        var seg: float = ((pts[i] as Vector2) - (pts[i - 1] as Vector2)).length()
        lengths.append(seg)
        total += seg
    var root: Vector2 = pts[0]
    var err: float = ((pts[pts.size() - 1] as Vector2) - target).length()
    var used := 0
    while err > tol and used < its and total > target.distance_to(root):
        used += 1
        pts[pts.size() - 1] = target
        for i in range(pts.size() - 2, -1, -1):
            var back: Vector2 = (pts[i] as Vector2) - (pts[i + 1] as Vector2)
            if back.length() > 0.000001:
                pts[i] = (pts[i + 1] as Vector2) + back.normalized() * float(lengths[i])
        pts[0] = root
        for i in range(1, pts.size()):
            var fwd: Vector2 = (pts[i] as Vector2) - (pts[i - 1] as Vector2)
            if fwd.length() > 0.000001:
                pts[i] = (pts[i - 1] as Vector2) + fwd.normalized() * float(lengths[i - 1])
        err = ((pts[pts.size() - 1] as Vector2) - target).length()
    return {"points": pts, "error": err, "converged": err <= tol, "iterations": used,
        "total_length": total, "reachable": total >= target.distance_to(root)}


## Look-at: the angle (radians, Godot 2D convention) a node at `from`
## turns to face `to`.
func look_at_angle(from: Vector2, to: Vector2) -> float:
    return (to - from).angle()


## Squash and stretch: a damped bounce of scale keyframes from an impact
## speed. With volume_preserve the x/y scales stay exact inverses, so
## the sprite squashes without gaining or losing area.
func squash_stretch(impact_speed: float, amount_scale: float = 0.01, stiffness: float = 8.0,
        frames: int = 12, volume_preserve: bool = true) -> Array:
    var keys: Array = []
    var squash := clampf(absf(impact_speed) * amount_scale, 0.0, 0.6)
    for i in frames:
        var t := float(i) / float(maxi(frames - 1, 1))
        var amount := squash * exp(-stiffness * t) * cos(TAU * 1.5 * t)
        var sx := 1.0 + amount
        var sy := (1.0 / sx) if volume_preserve else (1.0 - amount)
        keys.append({"t": t, "scale": Vector2(sx, sy)})
    return keys


## Foot placement: probe straight down from ray_origin against a ground
## line given as x-sorted {x, y} samples; interpolate the height under
## the probe and report contact when it is inside the ray's length.
func foot_placement(ray_origin: Vector2, ray_length: float, ground_samples: Array) -> Dictionary:
    var x := ray_origin.x
    var ground_y := NAN
    for i in range(1, ground_samples.size()):
        var a: Dictionary = ground_samples[i - 1]
        var b: Dictionary = ground_samples[i]
        var ax := float(a["x"])
        var bx := float(b["x"])
        if (x >= ax and x <= bx) or (x <= ax and x >= bx):
            var span := bx - ax
            var f := 0.0 if absf(span) < 0.000001 else (x - ax) / span
            ground_y = lerpf(float(a["y"]), float(b["y"]), f)
            break
    if is_nan(ground_y):
        return {"grounded": false, "contact": ray_origin, "distance": -1.0,
            "reason": "x outside the sampled ground range"}
    var distance := ground_y - ray_origin.y
    var grounded := distance >= 0.0 and distance <= ray_length
    return {"grounded": grounded, "contact": Vector2(x, ground_y), "distance": distance,
        "reason": "" if grounded else "ground outside the probe length"}


func _v2(arr) -> Vector2:
    return Vector2(float(arr[0]), float(arr[1]))


## The one operation: solve every chain in a rig config and report the
## ones that cannot reach or converge as solver_error issues.
func run(config: Dictionary) -> Dictionary:
    var issues: Array = []
    var solved := 0
    var chains: Array = config.get("chains", [])
    for chain in chains:
        var c: Dictionary = chain
        var cname := str(c.get("name", "chain"))
        match str(c.get("solver", "")):
            "two_bone":
                var r: Dictionary = solve_two_bone(_v2(c.get("root", [0, 0])),
                    _v2(c.get("target", [0, 0])), float(c.get("l1", 0)), float(c.get("l2", 0)),
                    int(c.get("bend_sign", 1)))
                if bool(r["reachable"]):
                    solved += 1
                else:
                    issues.append({"severity": "error", "kind": "solver_error", "path": cname,
                        "message": "Chain '%s': target is %.1f px away but the bones span only %.1f px - it can never reach." % [
                            cname, _v2(c.get("target", [0, 0])).distance_to(_v2(c.get("root", [0, 0]))),
                            float(c.get("l1", 0)) + float(c.get("l2", 0))],
                        "fix": "Lengthen the bones, move the target closer, or clamp the target into the reachable disc before solving."})
            "fabrik":
                var pts: Array = []
                for p in c.get("points", []):
                    pts.append(_v2(p))
                if pts.size() < 2:
                    issues.append({"severity": "error", "kind": "solver_error", "path": cname,
                        "message": "Chain '%s': a FABRIK chain needs at least two points." % cname,
                        "fix": "Add the chain's joint points to the config."})
                else:
                    var fr: Dictionary = fabrik(pts, _v2(c.get("target", [0, 0])),
                        int(c.get("iterations", -1)), float(c.get("tolerance", -1.0)))
                    if bool(fr["converged"]):
                        solved += 1
                    else:
                        issues.append({"severity": "error", "kind": "solver_error", "path": cname,
                            "message": "Chain '%s': FABRIK stopped %.2f px from the target (%s)." % [
                                cname, float(fr["error"]),
                                "chain too short" if not bool(fr["reachable"]) else "iteration budget too small"],
                            "fix": "Lengthen the chain or raise iterations/tolerance in the config."})
            "look_at":
                solved += 1
            "squash":
                var keys := squash_stretch(float(c.get("impact_speed", 0.0)))
                if keys.is_empty():
                    issues.append({"severity": "error", "kind": "solver_error", "path": cname,
                        "message": "Chain '%s': squash produced no keyframes." % cname,
                        "fix": "Give the impact a non-zero speed and at least two frames."})
                else:
                    solved += 1
            _:
                issues.append({"severity": "error", "kind": "solver_error", "path": cname,
                    "message": "Chain '%s' names solver '%s', which is not one of two_bone, fabrik, look_at, squash." % [cname, str(c.get("solver", ""))],
                    "fix": "Use one of the supported solver names."})
    return {"summary": {"chains": chains.size(), "solved": solved, "issues": issues.size()},
        "issues": issues}


func to_json(result: Dictionary) -> String:
    return JSON.stringify({"summary": result["summary"], "issues": result["issues"]}, "\t")


func to_markdown(result: Dictionary) -> String:
    var s: Dictionary = result["summary"]
    var lines: Array[String] = ["# Procedural Rig Report", "",
        "%d chain(s): %d solved, %d problems." % [s["chains"], s["solved"], s["issues"]], ""]
    for i in result["issues"]:
        lines.append("- [%s] %s" % [i["severity"], i["message"]])
    return "\n".join(lines) + "\n"
