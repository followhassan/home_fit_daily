# QA checklist

## Automated checks (run on 2026-10-21, Windows, Flutter 3.44.1)

| Check | Result |
| --- | --- |
| `dart format` (page width 100) | Clean |
| `flutter analyze` | No issues |
| `flutter test` | 127 passed, 3 skipped (the visual tools in `test/tools/`, which need environment variables) |
| `flutter build apk --debug` | Succeeded |
| `integration_test/app_smoke_test.dart` | **Not run** – no device or emulator was available |
| iOS build | **Not run** – no macOS machine |
| Release build / signing | **Not run** – no release keystore (see [RELEASE_BLOCKERS.md](RELEASE_BLOCKERS.md)) |

Visual review: key screens were rendered in widget tests with the real
fonts (`test/tools/screenshot_test.dart`) and every exercise figure was
rendered to contact sheets (`test/tools/figure_render_test.dart`) and
checked by eye. This is not a substitute for checking on a real device.

## Manual checks on a device

**None of the following have been performed yet.** Run them on at least one
small Android phone (≈360 dp wide), one large phone, one Android 13+ device
(notification permission) and, if shipping on iOS, one iPhone.

Mark each item with the device, OS version and date when checked.

### Install and first launch
- [ ] Fresh install starts in under ~3 s and shows onboarding
- [ ] "Skip setup" lands on Home with sensible defaults
- [ ] Completing onboarding stores every answer (check Settings → Profile)
- [ ] Upgrade from the prototype build keeps real workout history and drops placeholder values

### Workouts and player
- [ ] Every tab and the Settings screen open without errors
- [ ] Search, filters and sort in Workouts and Exercises behave as expected
- [ ] Exercise animations play smoothly; the system "remove animations" setting shows a still frame
- [ ] Start a workout: preparation, work, rest, switch-sides and rep confirmation all work
- [ ] Pause/resume, skip exercise, skip rest, extra rest time and finish early behave correctly
- [ ] Timer stays accurate over a 20+ minute session
- [ ] Sounds play without stopping music from another app; vibration works; both can be turned off
- [ ] Screen stays on while running and can turn off while paused
- [ ] Pressing Home or locking the phone pauses the workout; nothing advances in the background
- [ ] Force-closing the app mid-workout offers "Resume" on next launch, at the right step
- [ ] Summary shows correct times; effort and note are saved; nothing is saved twice
- [ ] Quitting before finishing any exercise saves nothing

### Plans
- [ ] Enroll with a start date today and in the future
- [ ] Plan day completes only when started from the plan
- [ ] Missed days appear after the date passes; move, skip and do-late work
- [ ] Pause and resume shift the schedule by the pause length
- [ ] Leave and restart a plan

### Custom workouts
- [ ] Build, reorder, edit and delete a custom workout; duplicate and remove steps
- [ ] Validation messages for empty name, no exercises and out-of-range values

### Progress and measurements
- [ ] Stats, streaks, chart and calendar match the session history
- [ ] Week starts on Monday; sessions near midnight land on the correct day
- [ ] Changing the device time zone does not move past sessions
- [ ] Measurements in metric and imperial; switching units converts display only

### Guide
- [ ] Articles open, bookmarks and read state persist, related links work

### Reminders
- [ ] Enabling reminders asks for notification permission only then
- [ ] Denying permission shows the explanation and leaves reminders off
- [ ] Reminders arrive on the chosen days near the chosen time (inexact)
- [ ] Reminders survive a reboot
- [ ] Tapping a reminder opens the app on Home
- [ ] Turning reminders off cancels them

### Backup and data
- [ ] Export creates a readable JSON file in the chosen location
- [ ] Import on a second device restores everything; "Undo import" restores the previous data
- [ ] Importing an invalid, truncated, oversized or newer-version file is rejected without changing data
- [ ] Reset progress clears history and plans but keeps profile, settings, favorites and measurements
- [ ] Delete all data returns to onboarding and cancels reminders
- [ ] Killing the app during an import leaves data in the old or new state, never mixed

### Offline and privacy
- [ ] Airplane mode from install onwards: every feature works
- [ ] Release APK manifest has no `INTERNET` permission
- [ ] No network traffic observed (e.g. with a proxy) during normal use

### Accessibility and display
- [ ] TalkBack/VoiceOver: all buttons labelled; player announces exercise changes
- [ ] Largest system font size: no clipped or overlapping text on key screens
- [ ] Light and dark themes have readable contrast
- [ ] Touch targets are at least 48 dp
- [ ] Small screens (≈320–360 dp wide) have no overflow
