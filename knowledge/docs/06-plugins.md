# 06 — Android plugins

## The v2 plugin system (current since Godot 4.2)

- A v2 plugin is an Android library built against the Godot
  Android library; its init class extends `GodotPlugin`, its
  manifest entries use the `org.godotengine.plugin.v2` prefix,
  and it is packaged through an EditorExportPlugin into the
  project's `addons/` — **not** as a `.gdap` file. The `.gdap` +
  `res://android/plugins` flow in Godot 3 / 4.0–4.1 docs is
  **deprecated**; v1 plugins are legacy.
- Building or bundling a plugin requires a **Gradle build**
  (docs/03). Plugins are enabled per export preset.
- Official starting points: `m4gr3d/Godot-Android-Plugin-Template`
  and the GDExtension-Android-Plugin-Template on GitHub.
- Before writing a plugin for simple Java interop, check the
  built-ins: Godot 4.4 added the `JavaClassWrapper` singleton and
  a bundled `AndroidRuntime` plugin, which cover many cases that
  used to need a custom plugin.

## Play Billing — the first-party plugin

- `GodotGooglePlayBilling` is first-party, but its repo **moved
  out of the godotengine org** to
  **godot-sdk-integrations/godot-google-play-billing**.
- Versioning: **1.x releases are for Godot 3; 2.0.0 and later are
  for Godot 4.** (Release 2.0.0 is the latest attested, Aug 2025 —
  check the releases page; see SOURCES.md.) The current build
  bundles **billing-ktx 8.0.0**, which satisfies Play's PBL 8+
  requirement (docs/05); it packages v2-style into
  `addons/GodotGooglePlayBilling/`.
- Purchases must be acknowledged or Google refunds them (the docs
  have said so since the Godot 3 era).
- Ignore the legacy Asset Library listing claiming a "Godot
  Google Play Billing 3.2.0" — its versioning matches nothing
  first-party; provenance unverified. Get the plugin from the
  godot-sdk-integrations releases.

## AdMob — Poing Studios, in its new home

- The maintained AdMob plugin is **Poing Studios'**, now in the
  monorepo **poingstudios/godot-admob-plugin** (docs at
  poingstudios.github.io/godot-admob-plugin). The old per-platform
  repos (`godot-admob-android`, `godot-admob-ios`) are **archived**
  — anything pointing at them is stale.
- Current line is **v5.x** (v5.1.0, Sep 2026, per the Asset Store
  changelog), supporting Godot 4.2+. v5 moved to the Google Mobile
  Ads Next-Gen SDK, dropped `config.gd` (configuration now lives
  in Project Settings under `admob/`), removed Smart Banners, and
  fetches its native binaries through the editor's AdMob Manager.

> Reminder for this family: games ship free with **no ads**
> (AGENTS.md rule 9). AdMob is documented here because "which
> plugin is real and current" is exactly the kind of question this
> repo exists to answer — not as a recommendation to add it.
