# Architecture

HomeFit is a single Flutter app with no server. It is organized in layers
that depend only downward:

```
features/ (screens)  ──▶  state/ (ChangeNotifiers)  ──▶  domain/ (pure Dart)
        │                         │                         │
        └──────────────▶  data/ (models, catalog, repositories, storage)
```

- **data/** – typed models, the read-only content catalog, repositories and
  the storage abstraction. No Flutter widgets.
- **domain/** – pure Dart rules: workout timeline and engine, statistics,
  plan scheduling, recommendations, validation, backup encoding and
  restore. Everything here is unit tested without Flutter bindings.
- **state/** – Provider `ChangeNotifier`s that load from repositories, call
  domain services, persist results and notify the UI.
- **features/** – screens and feature widgets.
- **app/** – `AppServices` (dependency bundle), provider wiring and
  navigation helpers. **core/** – theme, shared widgets, utilities and thin
  wrappers over platform plugins.

## Key decisions

| Decision | Reason |
| --- | --- |
| Keep **Provider** | It was already used in the repo and is sufficient; no migration risk. |
| Keep **Hive 2**, store **JSON documents** in `Box<String>` | No code generation, no new type adapters, tolerant decoding of individual records, simple backups. See [DATABASE.md](DATABASE.md). |
| Content as **bundled JSON** | Editable without code changes, validated by a test, parsed off the UI thread (`Isolate.run`). |
| **Derived** statistics and plan progress | Totals, streaks and plan completion are computed from session records every time, so they can never disagree with history or go stale after import/undo. |
| **Monotonic clock** for timing | Workout timing never uses wall-clock time, so clock or time-zone changes cannot distort it. |
| **Procedural figure animations** for demonstrations | No licensed media was available; see [ASSETS.md](ASSETS.md). |
| Platform plugins behind **interfaces** | `ReminderService`, `WorkoutFeedback`, `ScreenAwake` and `MonotonicClock` have fakes so state and widget tests run without a device. |

## Startup

`bootstrapServices()` (`lib/app/app_services.dart`):

1. Opens the Hive boxes. A box that cannot be opened produces a startup
   error screen offering to reset only that box.
2. Rolls back any interrupted multi-box write (restore journal).
3. Runs schema migrations (`SchemaMigrator`), including the one-time import
   of prototype data.
4. Loads and parses the catalog in a background isolate; debug builds also
   validate it and log problems.
5. Initializes local notifications and time zones.

## Dates and time

- Stored timestamps are UTC (`...AtUtc` fields).
- Every session also stores the **local calendar date** on which it ended.
  Day-based features (streaks, calendar, plan days, weekly goals) use that
  stored date, so travelling across time zones never moves a past workout to
  another day.
- `LocalDate` represents calendar days without time. Weeks start on Monday.

## Guided workout player

`WorkoutTimeline` expands a workout into an ordered list of segments:
10 s preparation, warm-up steps, main steps × rounds (with round rests),
cool-down steps, and a 5 s switch-sides segment for per-side timed
exercises.

`WorkoutEngine` (`lib/domain/workout_engine.dart`) is an explicit state
machine:

```
ready ─start─▶ running ─pause─▶ paused ─resume─▶ running
                  │  └─app hidden─▶ interrupted ─resume─▶ running
                  ├─finish early / last segment done─▶ finished
                  └─quit─▶ abandoned
```

- Time is accounted per interval into exactly one bucket (active, rest,
  preparation). Remaining time is computed from the clock rather than
  decremented, so late timer callbacks do not drift. A late callback
  carries at most 1 s of overshoot into the next segment.
- Repetition sets never finish by themselves; the user confirms them.
- Paused and interrupted time is never counted.

`WorkoutPlayerController` owns the engine, one periodic ticker, cues
(sound/haptics), the wakelock and persistence:

- A **checkpoint** is written on every structural change and when the app
  goes to the background. On next launch a checkpoint offers "Resume" or
  "Discard"; a restored session starts in `interrupted` and never advances
  on its own.
- **Finalization is idempotent**: the session ID is assigned before start,
  the final record is written once (repeated calls return the same result,
  a failed save can be retried) and the checkpoint is cleared afterwards.
- A session where no exercise was completed is not saved. Ending early
  saves a `partial` session; quitting after some work saves `abandoned`,
  which never counts as a completed workout.

No calories are estimated anywhere in the app.

## Statistics

`StatsService` derives everything from session records:

- Only `completed` sessions count as completed workouts and streak days.
- Active time includes completed and partial sessions; abandoned sessions
  are ignored.
- The current streak counts consecutive days with a completed workout,
  ending today, or yesterday if nothing has been done yet today.
- The weekly-goal streak counts consecutive Monday–Sunday weeks in which the
  goal was met; an unfinished current week never breaks it.

## Plans

Enrolling copies the 28-day schedule into an enrollment as **assignments**
with their own IDs and dates. A session completes a plan day only if it
was started from that assignment and stores its `planAssignmentId`;
doing the same workout from elsewhere does not tick a plan day.

`PlanScheduler` handles missed days (shown as missed, can be done late,
skipped or rescheduled), rescheduling (moves the day and shifts every later
unfinished assignment by the same amount, so workouts never double up),
pause/resume (shifts unfinished assignments by the pause length), leaving
and restarting. Only one active enrollment exists at a time.

## Recommendations

`RecommendationService` is deterministic preference matching, not coaching:
required equipment must be available, a low-impact preference is respected,
workouts above the user's level are excluded, and the rest are ranked by
closeness to preferred duration, goal fit and level fit, with recently
completed workouts ranked lower. If nothing matches, it falls back to
beginner-friendly workouts and says so.

## Reminders

`LocalReminderService` schedules one weekly notification per chosen day
(IDs 1001–1007) with inexact timing (`inexactAllowWhileIdle`), using the
device time zone. Permission is requested only when the user enables
reminders. The prototype's reminder (ID 0) is cancelled on upgrade.

## Privacy

- No network code. The `INTERNET` permission exists only in the debug and
  profile manifests (required by Flutter tooling), not in release.
- No analytics, crash reporting, ads or accounts.
- Android auto-backup is disabled so personal data is not copied to cloud
  backups. Export files are written only where the user chooses.

## Testing

| Layer | Location |
| --- | --- |
| Domain (timeline, engine, stats, scheduler, recommendations, validator) | `test/domain/` |
| Data (catalog content, backup/restore, migrations) | `test/data/` |
| Player controller with fake clock and storage | `test/features/` |
| Widget flows (onboarding, tabs, player, settings, data deletion) | `test/widgets/` |
| On-device smoke test (not yet run) | `integration_test/` |
