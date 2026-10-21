# Local storage

All personal data is stored on the device with Hive 2 (`hive`,
`hive_flutter`). Bundled content (exercises, workouts, plans, articles,
tips) is **not** stored in the database; it is read from `assets/data/` on
every launch.

## Format

Every box is a `Box<String>`. Each value is one JSON document (a record)
under a stable key. There are no Hive type adapters for current data and
no generated code.

Why JSON documents:

- A single damaged record can be skipped and reported without losing the
  rest of the box (`DocumentCollection` tracks unreadable keys).
- Backups are the same JSON, so export and import reuse the model code.
- Schema changes are plain data migrations, not adapter changes.

Timestamps are stored as UTC ISO-8601 strings (fields ending in `AtUtc`).
Calendar dates are stored as `YYYY-MM-DD` local dates. Body measurements are
stored in canonical metric units (kg, cm) and converted only for display.

## Boxes

| Box | Key | Value |
| --- | --- | --- |
| `hf_meta` | `schemaVersion` | Current schema version (`2`) |
| | `contentVersion` | Content version the data was last used with |
| | `restoreJournal` | Present only during a multi-box write (see below) |
| | `preImportSnapshot` | Data from before the last import, for "Undo import" |
| | `legacyMigration` | Marker written after prototype data was imported |
| `hf_profile` | `current` | `UserProfile` – name, level, goal, preferred duration and days, equipment, impact preference, units, weekly goal, onboarding flag |
| `hf_settings` | `current` | `AppSettings` – theme, sound, vibration, keep-awake, reminder settings |
| `hf_favorites` | `<kind>:<itemId>` | `FavoriteEntry` – favorite exercise or workout |
| `hf_sessions` | session ID | `WorkoutSession` – workout snapshot, status (completed/partial/abandoned), per-step records, active/rest time, effort, note, UTC timestamps, local completion date, optional plan assignment and enrollment IDs |
| `hf_active_session` | `current` | `ActiveSessionCheckpoint` – in-progress workout for crash recovery (`recoveryVersion` 1) |
| `hf_enrollments` | enrollment ID | `PlanEnrollment` – plan ID, status, start date, dated assignments, pause history |
| `hf_custom_workouts` | workout ID | `CustomWorkout` – user-built workout |
| `hf_measurements` | entry ID | `MeasurementEntry` – type, canonical value, local date |
| `hf_guide_state` | article ID | `ArticleReadingState` – bookmark, reading progress (0–1), last read time |

`hf_active_session` is device-local state and is never included in backups.

Sessions store a **snapshot** of the workout they were started from, so
history stays correct even if bundled content changes later.

## Schema versions and migration

| Version | Description |
| --- | --- |
| 1 | Prototype: typed Hive boxes `history_box`, `profile_box`, `settings_box`, `favorites_box`, `achievements_box`, `challenges_box` |
| 2 | Current: JSON documents in `hf_*` boxes |

`SchemaMigrator` runs at startup:

- Reads prototype boxes through read-only legacy adapters, converts history,
  profile, settings and favorites, writes them, then writes the
  `legacyMigration` marker and the schema version. Prototype boxes are
  deleted only after that, so an interrupted migration simply runs again.
- Placeholder values the prototype filled in (default weight, height, age,
  gender, estimated calories, cached streaks) are dropped, not shown as real
  data. Achievement and challenge data is not migrated.
- Data written by a newer schema version is never modified; the app shows an
  error instead of downgrading it.

**Hive type IDs 0–4 are permanently reserved** (0 workout history,
1 user profile, 2 achievement, 3 challenge, 4 settings) because prototype
files on users' devices may contain them. Never register a new adapter with
these IDs.

To add schema version 3: increase `SchemaMigrator.currentSchemaVersion`,
add an idempotent step for `2 → 3`, keep the version marker as the last
write, and add a test in `test/data/schema_migrator_test.dart`.

## Multi-box writes (journal)

Hive has no transactions across boxes. Operations that replace several
boxes – backup import, undo import, reset progress, delete all data – go
through `RestoreService.replaceBoxes`:

1. The raw contents of every affected box, including records that could not
   be decoded, are copied into `restoreJournal` in `hf_meta` and flushed.
2. Each box is replaced.
3. The journal is removed (for imports, the copy is kept as
   `preImportSnapshot`).

If step 2 fails, the boxes are rolled back immediately. If the app is killed
during step 2, startup finds the journal and rolls back. The change is
therefore all-or-nothing. This is covered by tests that inject write
failures (`InMemoryKeyValueStore.failWritesAfter`).

## Damaged data

- A record that cannot be decoded is skipped; the rest of the box still
  loads. Settings shows how many records could not be read and lets the
  user remove them after confirming.
- A box that cannot be opened at all shows a startup error screen that
  offers to delete only that box.
- Personal data is never deleted automatically to "fix" a problem.

## Backup file format

```json
{
  "format": "homefit.backup",
  "backupFormatVersion": 1,
  "schemaVersion": 2,
  "appVersion": "1.0.0+1",
  "exportedAtUtc": "2026-10-21T09:30:00.000Z",
  "payload": {
    "profile": { },
    "settings": { },
    "favorites": [ ],
    "customWorkouts": [ ],
    "sessions": [ ],
    "enrollments": [ ],
    "measurements": [ ],
    "guideStates": [ ]
  }
}
```

- Plain, unencrypted JSON. Users are told the file contains their personal
  data and is not protected.
- Import limit: 10 MB.
- A file is rejected as a whole if the format, version or any record is
  invalid, or if it was made by a newer schema version. Nothing is changed
  in that case.
- References to bundled content that no longer exists (for example a
  favorite of a removed exercise) are dropped with a warning shown before
  the user confirms the import.
