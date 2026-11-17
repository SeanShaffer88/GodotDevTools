# 09 — Android permissions

From the EditorExportPlatformAndroid class reference (the full
export-option list lives there) and the export docs.

## Declaring permissions: the preset

The Android export preset carries a `permissions/*` option group:
one boolean per Android permission (for example
`permissions/camera`, `permissions/access_fine_location`) plus
`permissions/custom_permissions` for arbitrary permission strings
that have no checkbox. Declaring a permission puts it in the
manifest; it does not grant it at runtime.

## Requesting at runtime

Dangerous permissions must be requested from the user at runtime
from code, with the OS singleton:

- `OS.request_permissions()` — ask for the permissions the preset
  declared.
- `OS.get_granted_permissions()` — see what the user actually
  granted.

Design for denial: a refused permission is a normal state, not an
error — the feature that needed it degrades, the game carries on.

## Discipline

- Request only what a shipped feature uses. Play reviews
  permission declarations, and every unused permission is review
  surface and user distrust for nothing.
- The preset's other option groups are listed in
  [reference/android-preset-options.md](../reference/android-preset-options.md);
  when an option's meaning is in doubt, the class reference — not
  a tutorial — is the authority.
