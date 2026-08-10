# hlth_app — conventions for agents

Flutter companion app for the **H59 BLE smart ring**. Local-first: the ring syncs
into Drift/SQLite, the UI reads only SQLite, Supabase is push-only.

## Commands

Every `run` and `build` needs the dart-define file or the app white-screens.

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # Drift + Freezed codegen

flutter run --dart-define-from-file=hlth.env.json
flutter build ios --config-only --dart-define-from-file=hlth.env.json   # then Xcode
flutter build appbundle --dart-define-from-file=hlth.env.json           # Android release
flutter build ipa        --dart-define-from-file=hlth.env.json           # iOS release

flutter analyze          # must print "No issues found!" — keep it clean
flutter test             # 243 tests across 28 files
flutter test test/vo2max_estimation_test.dart   # single file
```

`hlth.env.json` is gitignored and local-only; `hlth.env.example.json` is the
committed template. Never commit the real one.

## Architecture — do NOT impose Clean Architecture folders

```
lib/core/       layered: ble, database, models, repositories, scoring,
                services, sync, providers, routing, auth, bootstrap, config
lib/features/   FLAT per feature: <f>_screen.dart + <f>_providers.dart
                No domain/ data/ presentation/ subfolders. Ever.
lib/ui/         theme + shared widgets
```

Dependency order when adding a feature — this is the layer discipline, expressed
in the real paths:

```
tables.dart -> model (freezed) -> repository -> provider -> screen -> test
```

If a skill or plan asks for `features/<x>/domain|data|presentation`, translate it
to the above instead of creating the folders. 20+ existing features follow this.

## Stack

- **Riverpod 2.6**, ~128 **hand-written** providers. No `riverpod_generator`,
  no BLoC, no Cubit.
- **Drift/SQLite** is the source of truth, `schemaVersion` 13. Reference schema
  in `db/schema.sql`.
- **freezed** for immutable models; `json_serializable` for JSON.
- **go_router** for navigation.
- **Supabase** (`supabase_flutter`) — auth + push-only mirror of aggregated
  rollups. Bundles postgrest, so there is no separate HTTP client.
- Repositories are interface + impl pairs (`BpRepository` / `BpRepositoryImpl`).

## Native / platform channels

Native BLE access goes through the **frozen** `hlth/ble` MethodChannel
(49 methods, 14 callbacks) plus `hlth/realtime_stream` and
`hlth/realtime_stream_accel` EventChannels. The iOS Swift bridge mirrors the
Android Kotlin bridge so Dart stays platform-agnostic.

**Read `docs/FLUTTER_PLATFORM_CHANNELS.md` before touching anything native.**
Changing a channel signature means changing Dart, Kotlin, and Swift together.

## Scoring engines

`lib/core/scoring/` (`recovery_stability.dart`, `vascular_load.dart`,
`vo2max_estimation.dart`, `mental_wellness.dart`) is **vendored verbatim**.
Never edit engine logic — wrap it in a `*_service.dart` adapter instead.

- Scores persist to the `scores` table via `ScoreType`:
  recovery 0 / wellness 1 / longevity 2 / stress 3 / fitness 4 / cardioLoad 5.
- Missing signals are **redistributed, never fabricated**.
- Sleep metrics use the **sleep window** `[bedtime, wake)`, not the calendar day.

## Metric claims require evidence — non-negotiable

Never call a metric value correct, accurate, plausible, normal, or "about right"
without naming **in the same message**: (1) the algorithm it was checked
against, (2) the clinical reference, (3) the population dataset or physiologic
bound compared to. If you can't name all three, the answer is **"unvalidated"**
plus what's missing. That is a useful answer; a confident guess is not.

Reading the engine and finding it self-consistent is **not** validation —
correct code can implement a metric that measures nothing (LF/HF is invalid as a
sympathovagal index, Billman 2013, despite computing fine).

- Validate **base** metrics before composites. Recovery / Cardio Load /
  Wellness / Longevity look plausible while their inputs are broken.
- Always run the cross-metric possibility check (the canonical bug: respiratory
  rate 12 while HR is 130 — impossible, so it's a quality-gate failure).
- A single pass never marks something validated. Say that a **different** model
  must try to refute it.
- Reference corpus is in-repo at `docs/reference/` (11 docs, offline).
- Full protocol + per-metric reference map:
  `.claude/skills/metric-validation/` — invoke it for any metric question.

**Blood pressure:** `bp_formula.dart` ports the vendor SDK formula. Uncalibrated
SBP is `midpoint(100,120) + age_offset + (hr − 65) × 0.45`; DBP is `SBP − 40`.
No pressure sensor, no pulse-transit-time term. It is a deterministic function
of HR and age — never describe or validate it as a measurement.

## Testing

There is **no mocking library, and don't add one.** Every seam has a real
test double already available:

| Seam | How to test it |
|---|---|
| Pure logic (scoring, signal processing, decoders) | Call the function. See any `test/*_test.dart` |
| Repository | `NativeDatabase.memory()` from `drift/native.dart` |
| Provider | `ProviderContainer(overrides: [...])` |
| Platform channel | `TestDefaultBinaryMessengerBinding` + `setMockMethodCallHandler` |

Band-data bugs get a **replay test**: capture the real payload, decode it in a
unit test. `test/sync_adapters_bp_test.dart` and `test/sync_adapters_sleep_test.dart`
are the house pattern — follow them.

Currently covered: `core/scoring`, `core/services`, alert rules, sync decoders.
Uncovered: repositories, providers, screens.

## Dependencies — do NOT add these

| Package | Why not |
|---|---|
| `flutter_bloc`, `bloc_test` | We use Riverpod. A second state system is strictly worse |
| `dio`, `http` | Zero direct HTTP; `supabase_flutter` bundles postgrest |
| `get_it`, `injectable` | Riverpod *is* the DI container |
| `riverpod_generator` | All providers are hand-written; keep one style |
| `mocktail`, `mockito` | See Testing above — real doubles beat mocks here |

## Knowledge base — read before exploring source

| Doc | For |
|---|---|
| `docs/PROJECT_MASTER_GUIDE.md` | Overview + map of every other doc |
| `docs/FLUTTER_ARCHITECTURE.md` | Layers, folder map, Riverpod, Drift, engine pattern |
| `docs/FLUTTER_PLATFORM_CHANNELS.md` | The `hlth/ble` contract |
| `docs/BLUETOOTH_FLOW.md` | connect → bootstrap → monitoring → sync → score |
| `docs/API_REFERENCE.md` | `BleService` signatures, models, repos, services |
| `docs/TROUBLESHOOTING.md` | Symptom → root cause → fix. **Start here for bugs** |
| `docs/PROJECT_DECISIONS.md` | Why it's built this way (ADR log in all but name) |
| `docs/BUILD_GUIDE.md` / `docs/RELEASE_GUIDE.md` | Clone→run→build; store publishing |
| `docs/ANDROID_SDK_REFERENCE.md` / `IOS_SDK_REFERENCE.md` | Vendor SDK internals |
| `docs/plans/*.md` | Specs for in-flight and completed work |
| `.claude/skills/hlth-mobile-expert/` | H59 hardware quirks |

## H59 hardware quirks that cause most bugs

1. The band records nothing until `setScheduledMonitoring` runs.
2. Settings write-ack `isEnable` **lies** — trust the ~2s read-back or the
   overnight sample count.
3. `HRVReq` day index is shifted: 0 is always empty, **1 = today**, 2 = yesterday.
4. `sleepTime`/`wakeTime` are **local wall-clock** encoded (subtract the tz
   offset), unlike `zeroTime`-anchored metrics.
5. BP is recorded hourly by the timing monitor — pull via `getBpHistory` /
   `CMD_BP_TIMING_MONITOR_DATA`, not `getBpDay` (times out with `-4001`).

## Skill overrides

- **Never** run `flutter-project-init` or `/init`. This project already exists.
- Ignore any `flutter pub add` block a skill offers — the pubspec is correct.
- flutter-craft's verification commands omit the dart-define. Add it.
- Ignore flutter-craft's mockito/`bloc_test` test templates.
- Trivial one-line changes: skip the workflow skills and just make the change.
