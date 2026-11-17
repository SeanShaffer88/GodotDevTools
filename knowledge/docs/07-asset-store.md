# 07 — The Asset Store (and the Asset Library it replaced)

## Where addons come from now

- The **Godot Asset Store** (store.godotengine.org) is the current
  distribution channel: announced on the official blog as
  live/stable (beta began May 2026) and **integrated into the
  Godot 4.7 editor**. (The docs' Asset Store page still says
  "currently in beta" — the blog is the more recent statement;
  noted here so the discrepancy doesn't confuse.)
- The old **Asset Library** is **deprecated** and being set
  read-only. Assets were **not auto-migrated** — authors had to
  re-upload to the Store — so a missing or stale Store listing for
  a known addon usually means the author hasn't moved it yet; the
  project's GitHub releases are the fallback source.

## How an install lands in a project

Whichever storefront you use, the mechanics are the same:

1. The download lands in the project's **`addons/`** folder.
2. Editor plugins are enabled under **Project Settings →
   Plugins**.
3. Android plugins additionally need enabling in the Android
   export preset, and a Gradle build (docs/03, docs/06).
4. The addon becomes part of the project tree — commit it like
   any other source (docs/02), and record its version in the
   project docs, because storefronts do not pin versions for you.

## Choosing addons

- Prefer addons whose repo shows releases matching your engine
  version; an addon built for 4.2-era APIs may load in 4.7 and
  still misbehave.
- Check the license before bundling anything into a shipped game,
  and keep third-party code inside `addons/` — never copied into
  your own folders, where its origin gets lost.
