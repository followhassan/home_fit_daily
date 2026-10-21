# Implementation checklist

Status legend: `[x]` done and covered by automated tests or review ·
`[~]` done with limitations (see notes) · `[ ]` not done

"Done" means implemented and verified by unit/widget tests or visual review
of rendered screens. **No item has been verified on a physical device or
emulator** (see [QA_CHECKLIST.md](QA_CHECKLIST.md)).

## Foundations
- [x] Kept existing theme colors (black `#0D0D0D`, pink `#FF4FA3`), Provider and Hive 2
- [x] Removed prototype features that conflicted with the brief (calorie estimates, BMI, gender/age, runtime font download); old code moved to `legacy_prototype/`
- [x] Bundled Inter font (OFL); no runtime downloads
- [x] Layered structure: data / domain / state / features ([ARCHITECTURE.md](ARCHITECTURE.md))

## Persistence
- [x] JSON documents in `hf_*` boxes, schema version 2, content version
- [x] Migration from prototype (schema 1) data, idempotent, tested
- [x] Tolerant decoding of damaged records; startup error screen for unreadable boxes
- [x] Journaled multi-box writes with rollback (tested with injected failures)

## Content
- [x] 88 exercises, 32 workouts, 4 × 28-day plans, 22 articles, 20 tips
- [x] Automated content validator
- [~] Demonstrations: procedural stick-figure animations, not professional media ([ASSETS.md](ASSETS.md))
- [~] Content written but not professionally reviewed ([CONTENT.md](CONTENT.md))

## Features
- [x] Skippable onboarding with optional preferences
- [x] Home dashboard with real data only
- [x] Workouts hub, exercise library, search/filters/sort, favorites
- [x] Guided player: state machine, monotonic timing, background pause, checkpoint recovery, idempotent save
- [x] Summary with effort and notes (no calories)
- [x] Plans: enroll, assignment-linked completion, missed, reschedule, skip, pause/resume, leave, restart
- [x] Custom workout builder with validation
- [x] Progress, history, streaks, calendar, measurements with unit conversion
- [x] Guide with bookmarks and reading progress
- [x] Settings: preferences, cues, theme, reminders, backup/import/undo, reset, delete all, privacy, disclaimer, about, credits
- [~] Local reminders: implemented; delivery not verified on a device

## Quality
- [x] `dart format`, `flutter analyze` (no issues), `flutter test` (127 passed)
- [x] Debug APK builds
- [~] Integration smoke test written, not run (no device)
- [ ] Manual device QA
- [ ] iOS build
- [ ] Release signing, final application ID, launcher icon ([RELEASE_BLOCKERS.md](RELEASE_BLOCKERS.md))
