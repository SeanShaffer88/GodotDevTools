# 04 — Languages: GDScript, C#, GDExtension

## GDScript — the default

Godot's own scripting language carries no Android caveats anywhere
in the docs, needs no special editor build, and is what the demo
projects, the Asset Store ecosystem, and this family's projects
use. Default to it.

## C# (.NET) — supported on Android, officially experimental

- Since **Godot 4.2**, C# projects can be exported to Android; the
  docs label Android support **experimental** in both the export
  page banner and the C# platform-support page. (The often-quoted
  "C# cannot be exported to Android" line is from the 4.0 docs and
  is simply outdated.)
- C# requires the **.NET build of the editor** from
  godotengine.org — the standard executable has no C# support, and
  store builds (Steam etc.) do not include it either.
- Documented limits (4.3 docs, the most detailed official
  statement): projects must target .NET 7.0 or higher, and only
  the `arm64` and `x64` Android architectures are supported. The
  current C# page keeps the experimental label without restating a
  version floor — **treat the exact .NET floor as version-pinned
  and check the C# platform-support page for your version** (a
  third-party guide claims .NET 9+; unverified against official
  docs, see SOURCES.md).
- The standing contrast: C# projects still **cannot** be exported
  to the web platform. Android is not the blocked platform; Web
  is.

## GDExtension — native code when you need it

GDExtension libraries ship per-platform, per-architecture entries
in their `.gdextension` config, Android included (`android.debug` /
`android.release` for arm64, x86_64, …). Godot 4.2+'s v2 Android
plugins can also bundle GDExtensions. Reach for GDExtension for
performance-critical or native-library work, not as a default —
every native library you ship joins the 16 KB page-size scope in
docs/05.
