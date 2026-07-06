# HLTH Mobile — Project Master Guide

The entry point to the `hlth_app` knowledge base. `hlth_app` is a Flutter
companion app for the **H59 smart ring**: a native BLE bridge syncs the ring's
health data into a local database, sensor-agnostic engines compute daily scores
(Recovery, Cardio Load, VO2 Max), and Riverpod-driven screens render them.

## What this app is

- **Platform:** Flutter (Dart ^3.8.1), Android (QRing SDK) + iOS (QCBandSDK).
- **Device:** H59 BLE ring — HR, HRV, SpO2, sleep, stress, steps, BP (estimate),
  workouts.
- **Bundle:** `com.hlth.hlth_app` (Android) / `com.hlth.hlthApp` (iOS), v1.0.0+1.
- **Backend:** Supabase (push-only mirror). **Local-first:** SQLite is the truth.
- **Positioning:** wellness features, **not a medical device**.

## The 10-second mental model

```
H59 ring ──BLE──▶ Native bridge (Kotlin/Swift + vendor SDK)
   └─ MethodChannel `hlth/ble` + EventChannels ─▶ BleService (Dart, frozen contract)
       └─ SyncService.syncAll ─▶ repositories ─▶ Drift/SQLite
           └─ DailyAggregator (sleep-window rollup) ─▶ scoring engines ─▶ scores table
               └─ Riverpod StreamProviders ─▶ UI cards
```

## Documentation map

| Doc | Read it when you need… |
|---|---|
| [FLUTTER_ARCHITECTURE.md](FLUTTER_ARCHITECTURE.md) | The layers, folder map, state management, DB, engine pattern |
| [FLUTTER_PLATFORM_CHANNELS.md](FLUTTER_PLATFORM_CHANNELS.md) | The exact Flutter↔native message contract (49 methods, 14 callbacks, 2 streams) |
| [BLUETOOTH_FLOW.md](BLUETOOTH_FLOW.md) | The connect→bootstrap→monitoring→sync→score lifecycle |
| [API_REFERENCE.md](API_REFERENCE.md) | `BleService` Dart signatures, models, repos, services |
| [ANDROID_SDK_REFERENCE.md](ANDROID_SDK_REFERENCE.md) | QRing AAR internals (`com.oudmon.ble.*`) |
| [IOS_SDK_REFERENCE.md](IOS_SDK_REFERENCE.md) | QCBandSDK framework (`QCSDKManager`, `QCSDKCmdCreator`, models) |
| [BUILD_GUIDE.md](BUILD_GUIDE.md) | Clone → run → test → build |
| [RELEASE_GUIDE.md](RELEASE_GUIDE.md) | Play Store / App Store publishing (+ open signing gap) |
| [TROUBLESHOOTING.md](TROUBLESHOOTING.md) | Something's broken (start here for BLE/score bugs) |
| [PROJECT_DECISIONS.md](PROJECT_DECISIONS.md) | *Why* it's built this way + trade-offs |

Deeper background lives in `Transfered Files/Build guide/` (17 authoritative
specs: `hlth-ble-platform-channel`, `hlth-db-schema`, `hlth-sdk-data-inventory`,
`hlth-engineering-primer`, feature build guides) and the session memory.

## The five things that trip everyone up (read before touching BLE)

1. **The ring records nothing until scheduled monitoring is enabled** — now
   auto-enabled on connect; HRV silence usually means this didn't run.
2. **Settings write-acks lie on H59** — trust the ~2s read-back / overnight
   sample count, never `isEnable` from the write.
3. **HRV is stored under the wear-day index** — pull dayOffset 0 *and* 1.
4. **Accel only streams during raw PPG** (battery-heavy) — no continuous
   activity detection.
5. **Kotlin/Swift edits need a full `flutter run`**; Dart hot-restarts fine.

## Feature status (V1)

- **Shipped:** metric sync (HR/HRV/SpO2/sleep/steps/stress/BP-estimate),
  Recovery/Stability score, Cardio Load, **VO2 Max** (Åstrand-A + trend card +
  auto-prompt detector), alerts (AFib-screening, local notifications),
  nightly BP capture, sport mode, cloud push-sync.
- **In validation:** overnight HRV capture → full-confidence Recovery + Cardio
  Load production; background-tick reliability.
- **Pending:** Longevity/Body-Age composite, Mental Wellness, Menstrual, sleep
  apnea, PPG-morphology (blocked on new sensor), Android release signing, cloud
  restore.

## Working conventions (this codebase)

- Scoring engines are **vendored verbatim** — adapt around them, never edit the
  engine logic.
- Every score surface reads the **same provider** (no hardcoded values).
- Missing signals are **redistributed, never fabricated**.
- Verify against **source, not memory/docs**, before asserting behavior.
- Keep `flutter analyze` clean; add DI-fake service tests + pure-engine tests.

## Quick start

```bash
cd 99commerce_hlth_app
flutter pub get
dart run build_runner build --delete-conflicting-outputs
cp hlth.env.example.json hlth.env.json      # fill Supabase URL + anon key
flutter run --dart-define-from-file=hlth.env.json   # physical device + paired ring
```

Then open the **BLE Debug** screen to scan/connect and watch sync + scores.
