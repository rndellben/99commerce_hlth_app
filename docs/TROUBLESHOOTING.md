# Troubleshooting Knowledge Base

Real issues hit on this project, with root cause and fix. Grouped by area. Most
BLE issues trace back to a handful of **H59 firmware quirks** — start there.

## The H59 quirks that explain most bugs

| Quirk | Consequence |
|---|---|
| Dormant until monitoring enabled | HR/steps work but HRV/stress/BP silent |
| Settings **write-ack `isEnable` lies** (returns false when active) | Don't trust it; use the ~2s **read-back** |
| HRV stored under **wear-day** index | Must pull dayOffset 0 **and** 1 |
| **No scheduled-BP history** (`getBpDay` → `-4001` timeout) | Only on-demand `startBpMeasurement` works |
| **Accel only during raw PPG** | No continuous activity detection |
| Slow bootstrap (`SetTimeReq` ~1 min cold) | Enable monitoring **after** first sync, not on a fixed short delay |
| Retains only ~10 exercise records | Sync after every workout |
| Sleep is retrospective (no realtime event) | Can't recompute respiratory from a past window |

---

## Bluetooth / SDK

**HRV (and Cardio Load) always empty — `0 samples`**
- *Symptom:* Recovery low-confidence (~0.32), Cardio Load `noData`, Scores log
  `HRV sleep-window […]: 0 samples`.
- *Root cause:* scheduled monitoring never enabled → band records no HRV. It was
  only ever enabled from the debug screen; the connect bootstrap doesn't do it.
- *Diagnosis:* logcat `mSupportHrv` (must be `true`); BLE Debug → Scores shows
  the in-window HRV count.
- *Resolution:* `setScheduledMonitoring` is now **auto-called on every connect
  edge** (after the first sync). Confirm via the `hrv setting read-back:
  isEnable=true` log, then verify a non-zero overnight sample count.
- *Prevention:* never rely on the write-ack; validate with the read-back +
  overnight sample count.

**Scan shows 0 devices though the ring is connected in system Bluetooth**
- *Root cause:* an OS-paired peripheral stops advertising, so a service-filtered
  scan can't see it.
- *Resolution:* scan with **no service filter** + name-prefix allowlist; iOS
  additionally `retrieveConnectedPeripherals(withServices:)`.

**"BLE permission denied" on iOS despite Bluetooth on**
- *Root cause:* `Permission.bluetoothScan/Connect` are **Android-only**; on iOS
  the CoreBluetooth manager state is the real gate.
- *Resolution:* branch on `Platform.isIOS`; don't hard-block on the Android perms.

**`getBpDay` hangs ~15s then `-4001`**
- *Root cause:* H59 has no retrievable scheduled BP. *Resolution:* excluded from
  `syncAll`; use `startBpMeasurement` + the nightly-BP capture workaround.

**First sync lands samples with stale timestamps**
- *Root cause:* sync raced the band's clock-set handshake. *Resolution:* 1.5s
  settle delay after connect before syncing.

---

## Scores / data

**Home card and detail screen disagree (card=26, screen=0)**
- *Root cause:* the Recovery detail screen was a hardcoded placeholder
  (`score:0`); only the home card read the real provider.
- *Resolution:* both now read `latestRecoveryScoreProvider`.
- *Prevention:* every score surface must read the same provider, never literals.

**Contributing factor shows "Resting HR: 5" (looks like 5 bpm)**
- *Root cause:* the screen displayed the engine's 0–100 **sub-score**, not the
  raw metric. *Resolution:* show raw values (bpm/ms/min), colored by sub-score.

**VO2 Max / banner never appears after a walk**
- *Root cause:* intensity below the 40% HRR floor (a stroll won't qualify) —
  the engine correctly refuses. Also the detector read resting HR from an
  always-empty profile field.
- *Resolution:* need avg HR in the submaximal band (brisk/jog); detector now
  falls back to daily-metrics resting HR.

**Low Recovery on a normal night**
- *Root cause:* cold-start baseline (`HR vs cold-start 60bpm`) with <~5 nights
  banked makes a normal 73 bpm read as elevated. *Resolution:* self-corrects as
  the baseline matures; it's expected during calibration.

**Recovery/Cardio Load history empty on fresh install**
- *Root cause:* Supabase sync is **push-only** — no down-restore. *Prevention:*
  known gap; build a cloud-restore path or warn users on device change.

---

## Build / codegen

**"Missing SUPABASE_URL" crash on launch**
- *Fix:* run with `--dart-define-from-file=hlth.env.json`; for iOS run
  `flutter build ios --config-only …` before opening Xcode.

**Drift/Freezed errors after editing tables/models**
- *Fix:* `dart run build_runner build --delete-conflicting-outputs`.

**Native (Kotlin/Swift) edits not taking effect**
- *Fix:* full `flutter run` (not hot reload/restart) for native changes.

**iOS: "Cannot find 'BleManager' in scope" / framework not found**
- *Root cause:* BLE Swift files not in the Runner **Compile Sources**, or the
  framework not linked. *Fix:* add the Swift files to the target; link
  `QCBandSDK.framework` as **Do Not Embed**.

**iOS: `SLEEPTYPE`/enum constants "not in scope"**
- *Fix:* switch on the raw value (NONE0/SOBER1/LIGHT2/DEEP3/REM4/UNWEARED5).

**Android release crash on missing `com.oudmon.**` classes**
- *Root cause:* over-aggressive R8 stripping. *Fix:* rely on the AAR's bundled
  `proguard.txt`; don't strip SDK/Realtek packages.

---

## Tests

**`widget_test.dart` fails ("Found 0 widgets with text HLTH")**
- *Root cause:* pumps the full app which needs platform channels/DB unavailable
  under `flutter test`. Pre-existing, unrelated to feature work; all other
  tests pass. Prefer DI-fake service tests + pure-engine tests.

---

## Diagnostic toolkit

- **BLE Debug screen**: Scan/Connect, per-metric syncs, **Enable Mon**,
  **Scores** (logs sleep-window bounds + HRV sample count + score breakdown with
  `[redistributed]` markers), **Rec Hist**, **R-R**, battery drain test.
- **`adb logcat -s HlthBLE`**: bootstrap capabilities, monitoring read-backs,
  sync/step counts.
- **Scores button breakdown** is the fastest way to see *why* a score is what it
  is (which components were available/redistributed, z-scores, override flags).
