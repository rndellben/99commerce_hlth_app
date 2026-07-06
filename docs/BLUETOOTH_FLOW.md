# Bluetooth Lifecycle & Data Flow

End-to-end lifecycle of the H59 ring: discovery → connect → bootstrap →
monitoring enable → periodic sync → aggregation → scoring → UI. Covers both
platforms (Android QRing SDK, iOS QCBandSDK) behind the frozen `BleService`
contract.

> Key files: [`ble_service.dart`](../lib/core/ble/ble_service.dart),
> [`sync_service.dart`](../lib/core/services/sync_service.dart) (`SyncService` +
> `PeriodicSyncCoordinator`), [`BleManager.kt`](../android/app/src/main/kotlin/com/hlth/hlth_app/ble/BleManager.kt),
> [`ios/Runner/BLE/`](../ios/Runner/BLE/).

## Device model — H59 ring

- BLE-only; **no on-demand-by-default** — the ring is **dormant until
  scheduled monitoring is enabled**. This is the #1 gotcha: HR/steps/sleep may
  work while HRV/stress/BP are silent because monitoring was never written.
- Retains ~7 days of history; keeps only the **latest ~10 exercise records**.
- Sleep is **firmware-side and retrospective** (`syncSleepList` returns recorded
  sessions with stages) — there is **no real-time "now sleeping" event**.
- No per-epoch motion, no gyroscope. Accel only during raw-PPG capture.
- Capabilities read at bootstrap: `mSupportHrv`, `mSupportBloodOxygen`,
  `mSupportBloodPressure` = true; `mSupportTemperature` = false;
  `mNewSleepProtocol` = true (on the current unit).

## 1. Discovery (scan)

`startScan` → native scans with **no service-UUID filter** (the H59 doesn't
advertise the SDK service UUIDs), then filters by **name prefix**
(`H59`, `O_`, `Q_`, `R3L`, `QC`, `C6x`, `T8x/T9x`, …). iOS additionally calls
`retrieveConnectedPeripherals(withServices:)` because a peripheral already
paired at the OS level stops advertising and won't appear in a fresh scan.
Returns `[{id,name,rssi}]` after a ~10s window; results cached for `connect`.

## 2. Connect

`connect(deviceId)` returns **optimistically null**; the real outcome arrives
asynchronously:
- **Android:** GATT connect → `onServiceDiscovered` → `initEnable()` +
  `CMD_BIND_SUCCESS`.
- **iOS:** `CBCentralManager.connect` → on `didConnect`, bind the peripheral to
  `QCSDKManager.shareInstance().add(peripheral)` (the SDK needs this handle) →
  then `onConnected`.

On success native fires `onConnected{deviceName}` → Dart `connectionState`
stream flips to `connected`.

## 3. Post-connect bootstrap (native, `bootstrapBandAfterConnect`)

Fires ~1.5s after connect. Sequence:
1. `CMD_BIND_SUCCESS` — register the app as bonded.
2. `SetTimeReq(0)` — set band clock **and read capabilities** (`mSupportHrv`
   etc. logged here). **Can be slow** (~1 min observed on a cold connect).
3. Read battery.

> Bootstrap does **not** enable monitoring (see step 4). It only binds + sets
> time + reads capabilities.

## 4. Monitoring enable (the dormancy fix)

`setScheduledMonitoring` writes HR (10 min), HRV (30 min), SpO2 (60 min),
scheduled BP (60 min), stress (on) enables via `HeartRateSettingReq`,
`HrvSettingReq(true, interval)`, `BloodOxygenSettingReq`, `BpSettingReq`,
`PressureSettingReq`.

- **H59 quirk:** the WRITE ack's `isEnable` is **unreliable** (returns false
  even when active). A **read-back ~2s later IS ground truth**
  (`hrv setting read-back: isEnable=true`, [BleManager.kt:1151](../android/app/src/main/kotlin/com/hlth/hlth_app/ble/BleManager.kt#L1151)).
- **Where it's called:** historically only from the BLE Debug screen. Now
  **auto-enabled on every connect edge**, fired *after* the first sync (which
  proves the band is past its slow bind/time handshake) in
  `PeriodicSyncCoordinator._onConnectionChange`. Idempotent + self-healing.
- **Without this, HRV never records** → Recovery runs at low confidence and
  Cardio Load can't produce (it requires sleep RMSSD).

## 5. Periodic sync (HLT-11)

The **native scheduler** posts a tick every N minutes (default 30, set via
`setSyncIntervalMinutes`, clamped 5–60) → `onPeriodicSyncTick{intervalMin}` →
`PeriodicSyncCoordinator._onTick`. Also fires once on every
`disconnected → connected` edge (auto-sync on connect).

`_onTick` (all steps non-fatal, wrapped in try/catch):
1. Resolve active device (`DeviceRepository.getActiveForUser`); skip if none.
2. `SyncService.syncAll(userId, deviceId)`:
   - Pull HR, SpO2, sleep, steps, step-buckets, **HRV (dayOffset 0 AND 1)**,
     stress → normalize via `sync_adapters.dart` → repositories `insertMany`
     (idempotent on `UNIQUE(user_id, device_id, captured_at_utc, source)`).
   - `DailyAggregator.aggregateRecent` → one `daily_metrics` row/day
     (sleep-window medians for RHR/HRV/SpO2; see below).
   - `recoveryScore.computeForDay` → `cardioLoad.computeForLatestNight` →
     `vo2Max.computeForDay` (each non-fatal).
   - `cloudSync.enqueueRecentMetrics` + identity (Supabase outbox).
3. Cloud outbox drain, `alertEvaluator.evaluateAll`.
4. **Fall sweep** — short `startMeasureHrRaw` window, buffer accel, run the
   3-window fall state machine.
5. **Scheduled PPG capture** (once/day) — raw PPG → resting respiratory rate +
   HRV via Lomb-Scargle. Writes `daily_metrics.restingRespRateBpm`.
6. **Nightly BP** — H59 has no scheduled-BP history, so we fire our own
   `startBpMeasurement` once inside the night window.
7. **Activity detector** — scans last 30 min HR + step buckets; if sustained
   elevation (≥60% of HR ≥ resting+50% HRR, steps ≥1500) and no active workout,
   flags the "start a workout?" prompt (debounced).

Concurrency: `_inFlight` drops overlapping ticks. Raw captures (4–6) are
sequenced so two `startMeasureHrRaw`/active measurements never overlap.

## 6. Sleep-window aggregation (why "sleep-window" matters)

`DailyAggregator` computes **resting HR, HRV (median RMSSD/SDNN), SpO2** over
the detected sleep window `[bedtime, wake)`, not the whole day. Rationale
(Ryan, 2026-06-23): *daytime HRV is motion-contaminated; use the sleep window.*
Morning-window (04:00–09:00) is a fallback only when the night has no samples.
Missing metrics are left **null** (never fabricated) — downstream engines
redistribute weight rather than invent values.

## 7. Reconnection & recovery

- Auto-sync + monitoring re-enable fire on every `connected` edge → the app
  self-heals after a drop without user action.
- Connection edges dedup (band emits redundant `connected` events).
- A 1.5s settle delay after connect avoids racing the band's clock handshake
  (would otherwise land samples with stale timestamps).
- Background execution risk (Android Doze): all nightly metrics depend on the
  periodic tick actually firing overnight — a known validation item.

## 8. Real-time streaming (opt-in, battery-heavy)

`startMeasureHrRaw` → `hlth/realtime_stream` emits raw PPG + accel packets.
Used transiently by the fall sweep and scheduled PPG capture, then stopped.
Not kept on — continuous streaming would drain the ring.

## Error surfaces & timeouts

| Symptom | Cause | Handling |
|---|---|---|
| `ble.bluetooth.off` | adapter/CBManager not powered on | surface, wait for `onBleStateChange` |
| `ble.connect.not_found` | deviceId not in scan cache | rescan |
| `ble.connect.timeout` / `didFailToConnect` | band out of range / busy | retry on next edge |
| `-4001 task timeout` | `getBpDay` on H59 (unsupported) | BP day-sync excluded from `syncAll` |
| SDK write ack `isEnable=false` | H59 quirk | ignore ack, trust 2s read-back |
| 0 HRV samples overnight | monitoring not enabled / band cadence | auto-enable on connect; verify via Scores debug |

See [FLUTTER_PLATFORM_CHANNELS.md](FLUTTER_PLATFORM_CHANNELS.md) for the message
contract and [FLUTTER_ARCHITECTURE.md](FLUTTER_ARCHITECTURE.md) for how synced
data flows up to the UI.
