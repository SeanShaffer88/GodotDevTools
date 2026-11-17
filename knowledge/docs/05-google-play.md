# 05 — Google Play: the hard requirements in force

Checked 2026-11-17 against Play Console Help and Android
Developers pages. These floors rise on a yearly cadence — re-check
before every release (SOURCES.md has the exact pages).

## AAB is mandatory for new apps

Since August 2021, new apps must publish as an **Android App
Bundle**, and enrolling in **Play App Signing** is mandatory to
use bundles. Apps created before August 2021 may still update as
APKs; TV app updates have required AAB since June 2023. For a
Godot project this means: Gradle build on, Export Format = AAB
(docs/03).

## Target API: 36 (Android 16)

- **New apps and app updates must target API 36 since
  August 31, 2026** (API 35 applied from August 2025; the
  extension window to Nov 1, 2026 is past).
- Existing apps must target API 35+ to stay available to new users
  on newer devices. Other form factors run lower floors (Wear OS
  35, TV 34, XR 34, Automotive 35).
- Godot side: the 4.7.2 build template is reported to compile
  against API 36 by default even though the docs' SDK list still
  shows the 35 series (templates ahead of docs — Unverified
  against engine source, see SOURCES.md); Godot 3.6.3 raised its
  default target to 36 as well. Verify the produced AAB's target
  SDK in Play Console rather than assuming.

## 16 KB memory page sizes

- Every app targeting API 35+ must support 16 KB page sizes on
  64-bit devices. Pure managed apps comply automatically; anything
  shipping native `.so` libraries is in scope — **every Godot
  export ships native libraries** (`libgodot_android.so`,
  `libc++_shared.so`), so every Godot game is in scope.
- The general fix is NDK r28+ (16 KB-aligned by default) with AGP
  8.5.1+. In Godot, support landed in **4.5** (built on NDK r28b);
  exports from **4.4.1 and earlier trigger Play warnings**.
  Practical rule: **never ship a Play build from Godot older than
  4.5.**
- Enforcement timeline: originally November 1, 2025, with an
  extension path to May 31, 2026; the current official hard line
  is that **from February 1, 2027, updates without 16 KB support
  cannot be released**.

## Play Billing Library 8+

For apps that bill through Google Play: PBL 7 stopped being
acceptable for new apps and updates on August 31, 2026 (extensions
ended November 1, 2026), so **PBL 8+ is required** (the library
itself is at 9.1.0, June 2026; PBL 8's own deadline is Aug 2027).
The first-party Godot billing plugin's current build bundles
billing-ktx 8.0.0 and satisfies this — older plugin builds may
not (docs/06).

> This family's games are free — no paid unlocks, no ads, no data
> selling (AGENTS.md rule 9). The billing facts above matter
> because Play applies its rules to anything that bills, and
> because a future donation or companion app still has to clear
> them.
