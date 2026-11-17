# 01 — The engine and its versions

Checked 2026-11-17 against godotengine.org and the official
Release Policy page.

## Where Godot stands

- **Current stable: Godot 4.7.2** (the 4.7 feature release shipped
  June 2026; the download page for 4.7.2 is dated August 2026).
  **4.8 is in development** (beta builds already listed).
- Support windows per the Release Policy: a stable branch is
  supported at least until the next branch's first patch release,
  and **only the latest patch release of a series receives
  support**. Patch releases are backwards compatible and strongly
  recommended; minor upgrades are case-by-case.
- Recent lines: 4.6 (Jan 2026, supported), 4.5 (Sep 2025, partial
  support — security and platform fixes only), 4.4 and older (end
  of life).

## Godot 3.x

Still maintained, but winding down and explicitly best-effort:
3.6 (Sep 2024) is a supported branch and still shipping patches
(3.6.3, Nov 2026, raised its default Android target SDK to 36);
3.7 exists only as development builds with no planned release
date, and the policy page says 3.6 may be the last stable 3.x
branch. The docs' own recommendation: **use Godot 4.x for new
projects** — the standing exception is a project needing a feature
4.x dropped (e.g. GLES2/WebGL 1.0).

## Rules this implies

- Start new Android work on the current 4.x stable, and keep the
  editor, export templates, and project on the **same** version —
  templates and editor must match exactly.
- Budget for a yearly minor-version move: Play's target-API floor
  rises every August (docs/05), and riding a supported Godot line
  is how a small project keeps up without heroics.
- Pin the version in the project's docs and CI image tag; "latest"
  is not a version.
