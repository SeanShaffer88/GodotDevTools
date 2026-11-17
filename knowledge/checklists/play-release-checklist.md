# Google Play release checklist

Every line is a rule from docs/03 or docs/05. Re-check the Play
floors before every release — they rise yearly.

- [ ] Engine is Godot **4.5 or newer** (16 KB page support);
      editor and templates the same version
- [ ] Android Build Template installed; **Gradle Build** enabled;
      Export Format = **AAB**
- [ ] Release keystore in place (stored outside the repo, backed
      up); preset Release fields set; **Export With Debug
      unchecked**; passwords letters-and-numbers only, keystore
      and key passwords matching
- [ ] Produced AAB's target SDK verified as **API 36** (Play
      Console or bundle inspection — do not assume from the docs'
      SDK list)
- [ ] Play App Signing enrollment understood: the uploaded AAB is
      signed with the upload key; Google signs for distribution
- [ ] If the app bills through Play: billing plugin is the
      first-party 2.x line bundling **PBL 8+**, and purchases are
      acknowledged (docs/06)
- [ ] Permissions declared = permissions used (docs/09)
- [ ] Tests ran in CI with the executed-count check green
      (docs/08)
- [ ] Release notes carry only this version's changes
