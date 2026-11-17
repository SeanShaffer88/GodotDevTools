# AGENTS.md — rules for any AI working with Godot for Android

## The ground-truth hierarchy

1. The Godot documentation **for the exact engine version in use**
   (docs.godotengine.org has a page set per version — use the
   version switcher, never the first search result).
2. Google Play's own policy pages, for anything about publishing.
3. The project's own files (`project.godot`, `export_presets.cfg`,
   its pinned versions) for anything about the project.
4. This repo.
5. Community guides and videos — leads to verify, never authority.

## Non-negotiables

1. **Never invent** an API, an export option, a version number, or
   a Play requirement. If it is not on a fetched official page, it
   is marked Unverified or left out.
2. **Version-pin everything.** Godot's requirements change per
   release: JDK, SDK components, .NET floors, and Play targets in a
   tutorial for the wrong version are wrong answers. State the
   engine version in every plan and check the docs page for that
   version.
3. **Play releases need a Gradle build.** The pre-built template
   export produces APKs only; the AAB Google Play requires comes
   from the Gradle build (docs/03, docs/05).
4. **Ship Play builds from Godot 4.5+.** Earlier exports lack 16 KB
   page-size support and draw Play warnings (docs/05).
5. **GDScript is the default.** C# on Android is experimental and
   needs the .NET editor build; reach for it only with a stated
   reason (docs/04).
6. **Commit `export_presets.cfg`** (Godot 4.1+ stores no
   credentials in it); ignore only `.godot/` and `*.translation`
   (docs/02). Never commit a release keystore or its passwords.
7. **Plugins are v2.** The `.gdap` / `res://android/plugins` flow
   in old docs is deprecated (docs/06).
8. **Tests must prove they ran.** Headless runners can exit 0 with
   zero tests executed; a CI gate checks the count (docs/08).
9. **Free means free.** This family's games carry no ads, no paid
   unlocks, no data selling. Billing and ads are documented in
   docs/05–06 because the platform requires knowing them, not as
   features to add by default.
