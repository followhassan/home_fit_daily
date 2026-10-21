# Release blockers

The app is feature-complete in code and passes its automated tests, but it
is **not ready for a store release**. Items are ordered by importance.

## Must fix before release

1. **No device testing.** Nothing has been run on a phone or emulator. Run
   `integration_test/app_smoke_test.dart` and the manual checks in
   [QA_CHECKLIST.md](QA_CHECKLIST.md) on real Android devices (and iOS if
   shipping there). Timing, background behaviour, notifications, file
   pickers and audio can only be confirmed on a device.
2. **Content not professionally reviewed.** Exercise instructions,
   cautions, plans and articles were written without review by a qualified
   professional. See [CONTENT.md](CONTENT.md).
3. **Placeholder application ID.** Android uses `com.example.home_fit_daily`
   and iOS uses `com.example.homeFitDaily`. Stores reject `com.example`.
   Choose the final ID before the first release; it cannot change later
   without losing existing installs' data.
4. **Release signing.** The Android `release` build type is signed with the
   debug key (`android/app/build.gradle.kts`). Create an upload keystore,
   keep it out of the repository, and configure signing.
5. **Launcher icon.** Android and iOS still use Flutter's default icon.
6. **iOS not built.** No macOS machine was available. Before shipping on
   iOS: build in Xcode, set the bundle ID and team, check notification
   permission flow, and confirm the file picker export/import works.

## Should fix or decide before release

7. **Demonstration media are simplified stick figures** drawn in code (see
   [ASSETS.md](ASSETS.md)). They are honest about being simplified, but
   store copy must not describe them as professional demonstrations.
   Replacing them with licensed media is recommended.
8. **Privacy policy.** Stores require a privacy policy URL even for apps
   that collect nothing. The in-app privacy text matches current behaviour
   (no collection, no network); publish the same text.
9. **Store data-safety forms** must state: no data collected or shared,
   data stored on device only, user can delete all data in-app.
10. **Reminder reliability** on aggressive battery-saving Android builds
    (Xiaomi, Huawei, Samsung and others) is unverified. Reminders are
    inexact by design.
11. **Accessibility pass** with TalkBack/VoiceOver and the largest font
    sizes on real devices (widget tests cover text scaling only partly).

## Housekeeping

- `legacy_prototype/` contains the superseded prototype code (excluded from
  analysis and the build). Delete it once no longer needed for reference.
- A `git stash` entry (`stash@{0}`) holds a snapshot of the working tree
  taken before the prototype files were moved. Drop it when no longer
  needed (`git stash drop`).
- `CFBundleName` in `ios/Runner/Info.plist` is still `home_fit_daily`; the
  display name is already `HomeFit`.
