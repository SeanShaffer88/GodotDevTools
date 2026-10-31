# Native accelerator crate: research note

Status: **research only. No crate is built or shipped.** No tool may depend on native code (PROJECT_RULES: no third-party dependencies, no cross-tool dependencies).

## Question

Would an optional Rust GDExtension (via the `godot-rust/gdext` crate) speed up the suite's slow paths enough to justify a native build per platform?

## Measurements (2026-10-31)

Measured with Godot 4.3-stable headless on a 2-core Linux container. These are indicative numbers only; nothing was measured on Windows or macOS.

| Hot path | Tool | GDScript throughput | Example cost |
|---|---|---|---|
| Per-sample PCM decode loop (16-bit) | Audio Loudness and Clipping Auditor | ~3.7 million samples/s | 3-minute 48 kHz stereo track (17.3 M samples): ~4.7 s |
| Line-window hashing | Duplicate Code Detector | 20,000 lines in ~0.14 s | Large projects: seconds |
| File hashing | Patch Delta Estimator | `FileAccess.get_md5` is already native | No gain |
| Regex scans over scripts and scenes | most static tools | `RegEx` is already native (PCRE2) | Little gain |

## Findings

- The only clear hot spot is per-sample audio decoding. The tool already caps samples per file (`--max-samples`). A native loop would likely be one to two orders of magnitude faster, but this has not been measured.
- Everything else either already runs in engine code (regex, hashing, JSON) or finishes in under a second on fixture-scale input. Large-project timing is still unverified (see QUALITY.md).
- A GDExtension adds a native binary per platform and architecture, a Rust toolchain in CI, and an ABI tie to the Godot minor version. That cost is high compared with one slow loop.

## Recommendation

Do not build the crate yet. First:

1. Measure on a real large project (thousands of scripts and scenes, long audio files) on Windows, using the Micro-Benchmark Harness.
2. If audio decoding is the only bottleneck, try engine-side decoding first, for example reading `AudioStreamWAV.data` from imported resources. This stays in pure GDScript.
3. Reconsider native code only if measured scans exceed the per-tool budget of seconds on a mid-size project.

## If it is built later

- Crate `native/gdt_native` (gdext), exposing a `GdtNative` singleton with `pcm_stats(bytes, bits, format, max_samples) -> Dictionary` and `line_window_hashes(text, n) -> PackedInt64Array`.
- Each tool would check `Engine.has_singleton("GdtNative")` and otherwise fall back to its existing GDScript path. Results must be identical, and a test must compare both paths on the fixtures.
- CI would build the crate for Linux, Windows and macOS, run the full gate with the extension loaded and with it unloaded, and publish the binaries only as a separate optional download.
- This environment could not reach crates.io, so a build has not been attempted. Every claim above about native speed is unverified.
