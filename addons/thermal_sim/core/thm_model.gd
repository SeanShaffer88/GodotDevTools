## Mobile Thermal and Battery Drain Emulation Dock - model operation.
## A documented ESTIMATE, not a measurement - this project has no
## devices to measure, and the dock says so on its face. The model: a
## single-node RC thermal circuit per device profile (power in,
## dissipation out, temperature integrating over the workload timeline),
## a frame-budget check against the profile's refresh rate, and a
## battery-hours estimate from average watts. Workloads are pure data:
## [{t_s, cpu, gpu, fps}] sampled per second. Profiles carry honest
## names ("mid_android_estimate") and every constant is a round-number
## guess an importer can replace with their own measured numbers. The
## value is comparative - A vs B workload, before vs after an
## optimization - on the same guessed hardware, which is exactly what a
## dev without a device farm can act on.
extends RefCounted

## Degrees C gained per watt-second, dissipated per degree-second, and
## Wh per mAh - round-number guesses, replaceable per profile. HEAT_K
## is tuned so a sustained heavy workload crosses a low-end profile's
## throttle point inside a few minutes, which is the behaviour the
## estimate exists to compare.
const HEAT_K: float = 0.08
const WH_PER_MAH: float = 0.0037
## Estimated device profiles. Every number here is a documented guess.
const PROFILES: Dictionary = {
    "mid_android_estimate": {"ambient": 25.0, "throttle_temp": 45.0, "capacity": 90.0,
        "dissipation": 0.03, "base_w": 1.2, "cpu_w": 2.0, "gpu_w": 2.5, "screen_w": 1.0,
        "refresh": 60, "battery_mah": 4500},
    "flagship_phone_estimate": {"ambient": 25.0, "throttle_temp": 48.0, "capacity": 120.0,
        "dissipation": 0.045, "base_w": 1.5, "cpu_w": 3.0, "gpu_w": 4.0, "screen_w": 1.3,
        "refresh": 120, "battery_mah": 5000},
    "low_end_android_estimate": {"ambient": 25.0, "throttle_temp": 42.0, "capacity": 60.0,
        "dissipation": 0.02, "base_w": 0.9, "cpu_w": 1.5, "gpu_w": 1.5, "screen_w": 0.8,
        "refresh": 60, "battery_mah": 3000},
    "tablet_estimate": {"ambient": 25.0, "throttle_temp": 47.0, "capacity": 200.0,
        "dissipation": 0.06, "base_w": 1.8, "cpu_w": 3.0, "gpu_w": 4.0, "screen_w": 2.0,
        "refresh": 60, "battery_mah": 8000},
}
## Below this many estimated hours of play the drain is flagged.
var battery_hours_budget: float = 3.0


func power_w(profile: Dictionary, sample: Dictionary) -> float:
    return float(profile["base_w"]) + float(sample.get("cpu", 0.0)) * float(profile["cpu_w"]) \
        + float(sample.get("gpu", 0.0)) * float(profile["gpu_w"]) + float(profile["screen_w"])


## One RC step: temperature after dt seconds at the sample's power.
func thermal_step(temp: float, watts: float, profile: Dictionary, dt: float) -> float:
    var ambient := float(profile["ambient"])
    var gain := watts * HEAT_K / float(profile["capacity"]) * 100.0
    var loss := (temp - ambient) * float(profile["dissipation"])
    return temp + (gain - loss) * dt


## The one operation: simulate a workload timeline under a profile.
func simulate(workload: Array, profile_name: String) -> Dictionary:
    var issues: Array = []
    if not PROFILES.has(profile_name):
        return {"summary": {"profile": profile_name, "samples": 0, "issues": 1},
            "timeline": [],
            "issues": [{"severity": "error", "kind": "config_error", "path": profile_name,
                "message": "Unknown device profile '%s'; the estimated profiles are: %s." % [
                    profile_name, ", ".join(PROFILES.keys())],
                "fix": "Pick one of the listed profiles, or add your own measured numbers to PROFILES."}]}
    var profile: Dictionary = PROFILES[profile_name]
    var temp := float(profile["ambient"])
    var peak_temp := temp
    var throttle_at := -1
    var watts_sum := 0.0
    var budget_broken := 0
    var timeline: Array = []
    var t := 0.0
    for sample_raw in workload:
        var sample: Dictionary = sample_raw
        var dt := maxf(float(sample.get("dt_s", 1.0)), 0.001)
        var watts := power_w(profile, sample)
        watts_sum += watts * dt
        temp = thermal_step(temp, watts, profile, dt)
        peak_temp = maxf(peak_temp, temp)
        if throttle_at < 0 and temp >= float(profile["throttle_temp"]):
            throttle_at = t
            issues.append({"severity": "warning", "kind": "thermal_throttle", "path": profile_name,
                "message": "Estimated core temp crosses the %s throttle point (%.0f C) at t=%.0fs under this workload." % [
                    profile_name, float(profile["throttle_temp"]), t],
                "fix": "Cut sustained GPU load: cheaper shaders, lower physics tick, capped FPS. Compare runs with this dock before and after."})
        var fps := float(sample.get("fps", float(profile["refresh"])))
        var budget_ms := 1000.0 / fps
        var frame_budget_ms := 1000.0 / float(profile["refresh"])
        if fps < float(profile["refresh"]) * 0.9:
            budget_broken += 1
        timeline.append({"t_s": t, "temp_c": temp, "watts": watts, "fps": fps,
            "frame_ms": budget_ms, "budget_ms": frame_budget_ms})
        t += dt
    var seconds := t
    var avg_w := watts_sum / maxf(seconds, 0.001)
    var hours := float(profile["battery_mah"]) * WH_PER_MAH / maxf(avg_w, 0.001)
    if hours < battery_hours_budget:
        issues.append({"severity": "warning", "kind": "battery_drain_high", "path": profile_name,
            "message": "Estimated %.1f W average draws the %.0f mAh battery down in about %.1f h (budget %.1f h)." % [
                avg_w, float(profile["battery_mah"]), hours, battery_hours_budget],
            "fix": "The estimate is comparative, not absolute: use it to rank changes. Capping FPS to 30 in menus alone usually buys the biggest slice."})
    if budget_broken > 0:
        issues.append({"severity": "warning", "kind": "frame_budget_exceeded", "path": profile_name,
            "message": "%d of %d samples miss the %d Hz frame budget (%.1f ms)." % [
                budget_broken, timeline.size(), int(profile["refresh"]), frame_budget_ms_const(profile)],
            "fix": "Profile the heavy samples (Draw Call Profiler for render, Time Machine for frame history) and shave the worst."})
    return {"summary": {"profile": profile_name, "samples": timeline.size(),
            "peak_temp_c": peak_temp, "throttle_at_s": throttle_at,
            "avg_watts": avg_w, "battery_hours": hours,
            "budget_broken": budget_broken, "issues": issues.size()},
        "timeline": timeline, "issues": issues}


func frame_budget_ms_const(profile: Dictionary) -> float:
    return 1000.0 / float(profile["refresh"])


func run(workload: Array, profile_name: String) -> Dictionary:
    return simulate(workload, profile_name)


func to_json(result: Dictionary) -> String:
    return JSON.stringify({"summary": result["summary"], "issues": result["issues"]}, "\t")


func to_markdown(result: Dictionary) -> String:
    var s: Dictionary = result["summary"]
    var lines: Array[String] = ["# Thermal Simulation Report (ESTIMATE)", "",
        "Profile %s: %d samples, peak %.1f C, throttle at %s, avg %.2f W, about %.1f h battery. %d problems." % [
            s["profile"], s["samples"], s["peak_temp_c"],
            "%.0fs" % s["throttle_at_s"] if float(s["throttle_at_s"]) >= 0 else "never",
            s["avg_watts"], s["battery_hours"], s["issues"]], "",
        "Numbers are documented estimates for comparing changes, not device measurements.", ""]
    for i in result["issues"]:
        lines.append("- [%s] %s" % [i["severity"], i["message"]])
    return "\n".join(lines) + "\n"
