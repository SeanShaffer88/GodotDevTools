# Version matrix (checked 2026-11-17)

One page: engine line ↔ what its Android export needs ↔ what Play
demands. Detail lives in docs/01, docs/03, docs/05. Items marked †
are third-party attested, not confirmed on an official page (see
SOURCES.md).

| Godot | Status | JDK | Android SDK set (docs) | Play-ready? |
|---|---|---|---|---|
| **4.7.2** | Current stable | OpenJDK 17 | Build-Tools 35.0.1, Platform 35, NDK r28b (28.1.13356709), Platform-Tools 35.0.0+ | Yes — Gradle build → AAB; template targets API 36 †; Asset Store in-editor |
| 4.6 | Supported | OpenJDK 17 | Per the 4.6 docs page | Yes; on-device Gradle builds (GABE) arrived here |
| 4.5 | Partial support | OpenJDK 17 | Per the 4.5 docs page | Yes — **first line with 16 KB page support** |
| 4.4.1 and earlier | End of life | OpenJDK 17 | Build-Tools 34.0.0, Platform 34, NDK r23c | **No** — 16 KB warnings on Play |
| 4.2–4.3 | End of life | OpenJDK 17 | Per-version docs | Historically: C# Android + v2 plugins arrived in 4.2 |
| 4.0 | End of life | JDK 11 | — | No C# Android export; credentials could sit in export_presets.cfg |
| 3.6.3 | Best-effort, may be last 3.x | JDK 8 (3.x line) | Default target SDK raised to 36 in 3.6.3 | Legacy projects only; docs recommend 4.x for new work |

## Play floors in force (all apps)

| Requirement | Since | Note |
|---|---|---|
| AAB for new apps + Play App Signing | Aug 2021 | Pre-Aug-2021 apps may still update as APK |
| Target API 36 for new apps/updates | Aug 31, 2026 | Existing apps: API 35+ to stay discoverable |
| 16 KB page support (API 35+ targets) | Enforced in stages; hard line Feb 1, 2027 for updates | Godot: ship from 4.5+ |
| Play Billing Library 8+ | Aug 31, 2026 (extensions ended Nov 1, 2026) | First-party plugin's current build bundles 8.0.0 |
