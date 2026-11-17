# Android export preset — option groups

The Android preset's options, grouped as the
EditorExportPlatformAndroid class reference enumerates them. The
class reference is the authority for exact names and defaults;
this page is the map.

| Group | Covers |
|---|---|
| `architectures/*` | Which ABIs to include (arm64, arm32, x86_64, x86) — trim for APK size; unnecessary for AAB |
| `package/*` | App name, unique name (the application ID), version code/name |
| `keystore/*` | Debug and release keystore path, user (alias), password — passwords come from env vars in CI, never the repo |
| `gradle_build/*` | Gradle build on/off, export format (APK/AAB/AAR), min/target SDK, and Gradle-specific settings |
| `custom_template/*` | Custom export template binaries, when not using the official templates |
| `apk_expansion/*` | APK expansion (OBB) settings for the legacy APK route |
| `permissions/*` | One boolean per Android permission + `custom_permissions` — see docs/09 |
| `screen/*`, `graphics/*` and display options | Orientation, immersion, rendering driver choices as listed in the class reference |

Preset files are committed (docs/02). When a tutorial names an
option that is not in the class reference for your version, the
tutorial is for a different version — that mismatch is the most
common export bug in this ecosystem.
