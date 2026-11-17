# SOURCES.md — where the facts live

Checked 2026-11-17. Godot and Play both move on a yearly cadence;
re-check the starred rows before any release.

| Topic | Authority | Where |
|---|---|---|
| Current version, release policy * | Godot download archive + Release Policy docs page | godotengine.org/download/archive · docs.godotengine.org (about/release_policy) |
| Export prerequisites per version * | "Exporting for Android", versioned per release | docs.godotengine.org → Tutorials → Export |
| Gradle builds, AAB/AAR | "Gradle builds for Android" | docs.godotengine.org → Tutorials → Export |
| Export option names | Class reference: EditorExportPlatformAndroid | docs.godotengine.org → Classes |
| C# platform support * | "C#/.NET" docs section | docs.godotengine.org → Tutorials → Scripting → C# |
| Version control | "Version control systems" (Best practices) | docs.godotengine.org |
| Android plugins | "Godot Android plugins" (Platform → Android) | docs.godotengine.org |
| Play target API * | Play Console Help, target API policy (answer 11926878) | support.google.com/googleplay/android-developer |
| AAB requirement | Play Console Help (answer 2481797) | support.google.com/googleplay/android-developer |
| 16 KB page sizes * | Android Developers guide | developer.android.com/guide/practices/page-sizes |
| Play Billing versions * | Play Billing release notes + deprecation schedule | developer.android.com |
| Billing plugin | godot-sdk-integrations/godot-google-play-billing | github.com/godot-sdk-integrations |
| AdMob plugin | poingstudios/godot-admob-plugin | github.com/poingstudios |
| CI images | abarichello/godot-ci | github.com/abarichello/godot-ci |
| Asset Store | Godot blog + store | godotengine.org · store.godotengine.org |
| Demo projects | godotengine/godot-demo-projects | github.com/godotengine |

## Honestly Unverified (as of 2026-11-17)

- The exact .NET floor for C# Android exports in current Godot —
  the 4.3 docs say .NET 7.0+ (arm64/x64 only); a third-party guide
  claims .NET 9+. The official current C# page keeps the
  "experimental" label without a floor. Check that page for your
  version before printing a number.
- Whether 4.7.2's build template compiles against API 36 by
  default (third-party attested; the docs' SDK list still shows
  the 35 series — the templates appear to run ahead of the docs).
- The exact latest release of the billing plugin (2.0.0 attested
  August 2025; check the repo's releases page).
- The official Discord invite string and the godot-ci images'
  exact bundled SDK components.
