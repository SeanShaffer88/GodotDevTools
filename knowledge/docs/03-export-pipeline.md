# 03 — The Android export pipeline

From the official "Exporting for Android" and "Gradle builds for
Android" pages. **Component versions are pinned per Godot
version** — the numbers below are the current-docs set; the same
page for your exact editor version is the authority (a 4.4-era
page lists the 34-series SDK and NDK r23c, which are wrong for
current Godot).

## Prerequisites

1. **OpenJDK 17.** Higher JDK versions are supported; 17 is the
   recommended one for compatibility and stability. (Godot 4.0
   wanted JDK 11 and Godot 3 wanted JDK 8 — another version trap.)
2. **Android SDK** via Android Studio (Iguana 2023.2.1+) or
   `sdkmanager`. Current-docs component set:

   ```
   sdkmanager --sdk_root=<android_sdk_path> "platform-tools" "build-tools;35.0.1" "platforms;android-35" "cmdline-tools;latest" "cmake;3.10.2.4988404" "ndk;28.1.13356709"
   ```

   Platform-Tools must be 35.0.0 or later. On Linux, do not use a
   distro-packaged SDK — the docs warn it is often outdated.
3. **Export templates** matching the editor version, installed via
   Editor → Manage Export Templates.
4. **Point the editor at the toolchain** (Editor Settings →
   Export → Android): `Java SDK Path` and `Android Sdk Path`.
   These are per-user editor settings, not project files.

## The two export methods

**A. Pre-built template export (default).** Add an Android preset
(Project → Export) and export: Godot packages the project into the
pre-built template. Output is **APK only** — right for devices,
sideloading, and other stores, never for Google Play.

**B. Gradle build (required for Play).** Project → **Install
Android Build Template…** installs a Gradle project under
`res://android/build`; enable **Gradle Build** in the preset and
every export runs Gradle. Use it to:

- export an **AAB** for Google Play (the reason most projects
  switch),
- export an AAR to embed in another Android app,
- customize the Android template project,
- add Android/Java/Kotlin SDKs and libraries to the build.

The native `.so` stays precompiled — no C++ toolchain or engine
source build is needed. (Older docs call this "Custom builds";
same mechanism. Since Godot 4.6 the Android editor can also run
Gradle builds on-device via the separate Godot Android Build
Environment app.)

## Signing

- **Release keystore**, generated once and kept safe **outside**
  the repo:

  ```
  keytool -v -genkey -keystore mygame.keystore -alias mygame -keyalg RSA -validity 10000
  ```

  Fill the preset's Release / Release User / Release Password
  fields. Two documented gotchas: the keystore password and the
  key password currently **must be the same**, and passwords
  should use only letters and numbers — special characters may
  cause errors. Uncheck **Export With Debug** for release exports.
- **Debug builds** use the debug keystore settings; for headless
  and CI exports both keystores are supplied by environment
  variables: `GODOT_ANDROID_KEYSTORE_DEBUG_PATH/_USER/_PASSWORD`
  and `GODOT_ANDROID_KEYSTORE_RELEASE_PATH/_USER/_PASSWORD`, plus
  `GODOT_SCRIPT_ENCRYPTION_KEY` for script encryption.
- One-click deploy trap: a device holding the same package name
  signed with a different key must have it uninstalled first.

## Icons and size

- Main icon at least 192×192 px; adaptive-icon foreground and
  background at least 432×432 px; optional themed (monochrome)
  icon at least 432×432 px. Godot generates the lower densities
  and has a documented fallback chain.
- A default APK bundles both ARMv7 and ARMv8 libraries; uncheck
  an architecture in the preset to trim it. For AAB this is
  unnecessary — Google splits the bundle on their side.
