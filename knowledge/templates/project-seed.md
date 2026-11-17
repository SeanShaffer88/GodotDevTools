# Seeding a new Godot Android project

In order (detail in the docs named):

1. **Pin the engine version** — current stable (docs/01); editor
   and export templates the same version.
2. **Language: GDScript** unless a stated reason says otherwise
   (docs/04).
3. Create the project; copy
   [`godot.gitignore`](godot.gitignore) in as `.gitignore`; commit
   from the first day (docs/02).
4. Set the package unique name and version in the Android preset
   **before** the first device install — changing the application
   ID later means a new app on every device and in Play.
5. Generate the release keystore, store it and its passwords
   **outside** the repo, and back them up — losing them before
   Play App Signing enrollment is recoverable; losing the upload
   key afterwards is a support ticket (docs/03).
6. Install the Android Build Template (Gradle build) from the
   start if Play is the target — it is the only AAB route
   (docs/03, docs/05).
7. Add the test framework (GUT or GdUnit4) with the
   tests-actually-ran check wired into CI (docs/08).
8. Record the project's facts in its own docs: engine version,
   target API, package name, where the keystore lives (not its
   passwords).
