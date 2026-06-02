# `hlth_app/db/`

Schema inspection artifacts. **Not** the runtime database — that lives on
each user's device.

## Files

| File | What it is | When to touch it |
|---|---|---|
| [schema.sql](schema.sql) | Human-readable SQL mirror of the runtime schema | When the runtime schema changes |
| [hlth_app_schema.db](hlth_app_schema.db) | Empty SQLite file built from `schema.sql`, for visual inspection | Regenerate after editing `schema.sql` |
| [build_schema_db.py](build_schema_db.py) | Rebuilds `hlth_app_schema.db` from `schema.sql` | Run after edits |

## Single source of truth

The Dart code at [`lib/core/database/database_helper.dart`](../lib/core/database/database_helper.dart)
is the **runtime** source of truth. The schema runs on each user's device,
gets created lazily on first DB access, and migrates forward via
`onUpgrade`.

`schema.sql` here is a **mirror** for documentation and inspection. When
the runtime schema changes:

1. Edit `database_helper.dart` (`_onCreate` and/or `_createV2Tables`)
2. Bump the `version:` arg in `openDatabase(...)`
3. Add an `onUpgrade` step
4. Update `schema.sql` to match
5. Run `python build_schema_db.py`

## Why two artifacts (.sql + .db)?

- `.sql` is text — diffable, reviewable in PRs, opens in any editor
- `.db` is binary — opens in DB Browser for SQLite, gives a visual
  table/index browser without needing to read SQL

## Opening the .db in DB Browser

1. Install DB Browser for SQLite (free, https://sqlitebrowser.org)
2. Open `hlth_app_schema.db`
3. Browse the "Database Structure" tab to see tables, columns, indices

## Pulling the *real* runtime DB from your device

If you want to inspect data the app actually collected:

```
adb exec-out run-as com.hlth.hlth_app cat databases/hlth_app.db > real.db
```

Open `real.db` in DB Browser. It has the same schema as
`hlth_app_schema.db` but with your actual rows.

## What's in v2

Per [hlth-app-implementation-plan.md](../../hlth-app-implementation-plan.md)
Phase 0 + [hlth-engineering-primer.md](../../hlth-engineering-primer.md) §5.

**7 canonical tables** (from the plan):
`user_profile`, `daily_metrics`, `raw_ppg_segments`, `sleep_sessions`,
`exercise_sessions`, `baselines`, `alerts`

**6 v2 raw-band-reading tables** (intermediate layer between band sync
responses and aggregated `daily_metrics`):
`hr_readings`, `spo2_readings`, `hrv_readings`, `bp_readings`,
`sleep_stages`, `step_buckets`
