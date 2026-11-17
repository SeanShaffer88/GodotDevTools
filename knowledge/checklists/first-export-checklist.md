# First Android export checklist

Getting from a fresh project to a running build on a device
(docs/02–03).

- [ ] Editor and export templates on the same pinned version
      (current stable)
- [ ] OpenJDK 17 installed; editor's `Java SDK Path` set
- [ ] Android SDK installed with the component set from the
      Exporting for Android page **for your version**; `Android
      Sdk Path` set
- [ ] Project created with the `.gitignore` from
      [templates/godot.gitignore](../templates/godot.gitignore);
      first commit made
- [ ] Android preset added; package unique name and version set
- [ ] Icons in place (main ≥ 192×192, adaptive pair ≥ 432×432)
- [ ] Debug export to APK succeeds
- [ ] One-click deploy: preset marked Runnable, USB debugging on,
      game runs on the device
- [ ] Permissions trimmed to what shipped features use (docs/09)
