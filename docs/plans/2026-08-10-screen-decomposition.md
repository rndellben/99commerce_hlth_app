# Screen decomposition — `ble_debug_screen.dart` + `settings_screen.dart`

**Date:** 2026-08-10
**Status:** proposal — no code changed in this pass
**Scope:** `lib/features/debug/ble_debug_screen.dart` (3,260 lines) and
`lib/features/settings/settings_screen.dart` (2,022 lines). Together 5,282 of
~20,900 lines under `lib/features/` — 25% of all feature code in two files.

---

## 1. Constraints this plan works under

- **Flat feature layout stays flat.** Extractions land in
  `lib/features/<f>/widgets/` (leaf widgets), `lib/features/<f>/<name>_screen.dart`
  (route destinations), `lib/features/<f>/<name>_controller.dart` (feature logic),
  or `lib/core/` (logic with more than one consumer). No `domain/`, `data/`, or
  `presentation/` folders.
- Both target paths already have precedent in this repo:
  `lib/features/activity/widgets/vo2max_card.dart` for the widgets folder, and
  `lib/features/blood_pressure/bp_controller.dart` for a feature-local
  controller — whose docstring already states this exact intent:

  > Extracted from `blood_pressure_screen.dart` so the widgets only render state
  > and forward intents; everything that touches BLE or repositories lives here
  > where it can be tested without a widget tree.

  This plan is that same move, applied twice more.
- `lib/features/settings/` already holds sibling screens
  (`monitoring_screen.dart`, `notifications_screen.dart`, `device_settings_screen.dart`,
  `reminders_screen.dart`), so splitting screens out of `settings_screen.dart`
  restores an existing convention rather than inventing one.
- No new dependencies. No mocking library. Tests use the real doubles listed in
  `CLAUDE.md`.
- Every step ends with `flutter analyze` printing **No issues found!**

## 2. How each seam was judged

Vocabulary from the codebase-design skill:

- **Depth** — how much behaviour a caller gets per unit of interface they must
  learn. Deep = small interface, large implementation. Shallow = interface nearly
  as complex as the implementation.
- **Deletion test** — imagine deleting the module. If complexity vanishes, it was
  a pass-through. If it reappears across N callers, it was earning its keep.
- **Two adapters means a real seam.** One adapter is just indirection.
- **The interface is the test surface.** If you want to test past an interface,
  the module is the wrong shape.

Each candidate below is classified by dependency category, because that decides
how it gets tested: **in-process** (pure — merge and test directly),
**local-substitutable** (Drift memory DB, `SharedPreferences.setMockInitialValues`),
or **already at a seam** (`BleService`, repositories).

## 3. What is actually in these files

### `settings_screen.dart` — seven screens in one file

| Lines | Symbol | Kind |
|---|---|---|
| 18–235 | `SettingsScreen` + `_confirmLogOut` | root screen (the only public thing) |
| 237–270 | `_SettingsTile` | leaf widget |
| 272–967 | `_ProfileViewScreen` | screen, 696 lines |
| 969–1017 | `_EditableProfileRow` | leaf widget |
| 1019–1081 | `_ComingSoonScreen` | screen |
| 1083–1271 | `_GeneralSettingsScreen` | screen |
| 1273–1308 | `_GeneralTile` | leaf widget |
| 1310–1451 | `_IntegrationsScreen` | screen |
| 1453–1485 | `_IntegrationTile` | leaf widget |
| 1487–1571 | `_AboutScreen` | screen |
| 1573–1600 | `_AboutTile` | leaf widget |
| 1602–1631 | `_LegalTextScreen` | screen |
| 1633–1682 | `_kTermsText`, `_kPrivacyText` | 50 lines of prose |
| 1684–1857 | `_SupportScreen` | screen |
| 1859–1890 | `_SupportActionTile` | leaf widget |
| 1892–1982 | `_SubmitTicketScreen` | screen |
| 1984–2022 | `_SupportTile` | leaf widget (ExpansionTile) |

This file is not one deep module — it is seven route destinations, seven tile
widgets and a legal document sharing a filename. There is no interface to
deepen; the work is **relocation**, and it is close to mechanical.

### `ble_debug_screen.dart` — one 2,563-line State class

| Lines | Region |
|---|---|
| 66–196 | ~50 state fields |
| 210–370 | `_attachListeners` — 12 stream subscriptions, incl. a 50-line PPG buffering loop |
| 469–761 | scan / permissions / aliases / rename / connect / disconnect |
| 763–1445 | 16 band-sync handlers (call service → 10–30 `_push` lines each) |
| 945–1111 | `_computeScores` — 167 lines of score orchestration + logging |
| 1671–1832 | Fall Watch state machine |
| 1834–1947 | capture buffers + capture start/stop |
| 2172–2420 | `_toolBtn` + `build` |
| 2422–2499 | battery drain test |
| 2501–2612 | clipboard exports (R-R, raw multi-channel) |
| 2632–2684 | `_CollapsibleSection`, `_LogEntry` |
| 2686–2754 | `_StatusPanel` |
| 2756–2910 | `_BatteryTestPanel` |
| 2912–3260 | `_ActionBar` — **40 constructor parameters** |

Here there *are* real modules to find, and one of them turns out to be a
correctness problem, not just a size problem.

## 4. Findings, ranked

| # | Seam | Kind | Lines moved | Why it earns its keep |
|---|---|---|---|---|
| **D2** | Fall Watch | duplicate logic, diverged | ~162 | Debug tool and production service disagree — see below |
| **D1** | `_ActionBar` | shallow module | ~400 | 40-param interface hiding nothing; 4 edit sites per new button |
| **D4** | Sync log formatters | untestable pure logic | ~450 | Pure `SyncStepResult → List<String>`, reachable today only by tapping a button with a band attached |
| **D3** | PPG capture buffers | unenforced invariant | ~165 | 8-channel 1:1 alignment held together by a comment |
| **S1–S4** | Settings screens/tiles | misfiled | ~1,800 | Seven route destinations in one file |
| **D5** | Battery drain test | self-contained feature | ~230 | Clean cut, zero coupling to the rest |
| **D6** | Debug log | shared substrate | ~120 | `_push` has ~200 call sites; needs a stable home |
| **S5** | Profile edit dialogs | repeated boilerplate | ~350 | Also fixes two undisposed `TextEditingController`s |

### D2 is a correctness finding, not a tidiness one

The debug screen's Fall Watch (`ble_debug_screen.dart:1671–1832`) and
`lib/core/sync/fall_sweep_service.dart` are **two implementations of the same
pipeline** — subscribe to `rawPpgEvent`, collect accel triples, calibrate a local
1 g reference, rescale to milli-g, run `FallDetector`. They have drifted apart on
all three parameters that matter:

| | Debug screen Fall Watch | `FallSweepService` (production) |
|---|---|---|
| 1 g calibration | **mean** of first ~5 s (`ble_debug_screen.dart:1752–1759`) | **median** of the whole window (`fall_sweep_service.dart:88–95`) |
| Sample rate | hardcoded `_fallWatchFsHz = 24` (line 154) | measured, `samples / durationS` (line 116) |
| Minimum samples | `((10+1+0.3) * 24).round() + 10` = 282 (line 1789) | 50 (line 75) |

`FallSweepService` documents *why* it uses the median:

> Using median (not mean) so a real impact doesn't pull the reference up and
> dilute the freefall threshold.

The debug screen uses the mean the production path explicitly rejects, at an
assumed rather than measured sample rate. So the tool a human uses to verify fall
detection can classify the same motion differently from the code that ships. That
is the failure mode the whole debug screen exists to prevent.

This is also the skill's "two adapters means a real seam" case exactly: the
interface was never named, so the two implementations diverged silently.

**Proposal:** one pure module, two adapters.

```
lib/core/processing/fall_window_analyzer.dart   // pure: triples + fs → 1g + events
lib/core/services/fall_watch_session.dart       // live: ring buffer, timers, BLE restart
```

`FallWindowAnalyzer` interface — small, deep, in-process, directly testable:

```dart
FallWindowResult analyze({
  required List<int> accelXRaw,
  required List<int> accelYRaw,
  required List<int> accelZRaw,
  required double samplingRateHz,
});
// hides: median 1g calibration, raw→milli-g rescale, minimum-sample gate, detect()
```

`FallWatchSession` interface — what the debug screen keeps:

```dart
void start();  void stop();  void addSample(int x, int y, int z);
Stream<FallDetection> get events;
FallWatchStatus get status;   // calibrated, lastMagG, lastXyzRaw, eventCount
// hides: 20 s ring buffer, 1 Hz eval cadence, buffer re-arm after a fire,
//        540 s startMeasureHrRaw restart (H59 only streams accel during capture)
```

Then `FallSweepService.run()` is rewritten to call `FallWindowAnalyzer` as well.
Its BLE capture-and-buffer half stays where it is. Two adapters, one
implementation, one place to change the calibration rule.

`lib/core/processing/` is chosen for the pure half because `fall_detector.dart`
already lives there and this is its immediate neighbour. If you'd rather keep the
extraction inside the two directories named in the brief, both halves can go in
`lib/core/services/` — nothing else in the plan depends on the choice.

**Test surface gained:** `test/fall_detector_test.dart` covers the pure detector.
Nothing covers calibration, windowing, or re-arm today — they can only be
exercised by wearing a ring and falling over. `FallWindowAnalyzer` is a pure
function: feed synthetic triples (flat → no event; freefall-then-impact → one
event; impact during calibration → assert the median reference is not dragged up)
and assert. That last case is the regression test for the finding above.

**Note, not a defect:** `ble_debug_screen.dart:1748` reads
`xRaw * xRaw + yRaw * yRaw + zRaw * zRaw.toDouble()`. The `.toDouble()` binds to
`zRaw` alone, so the sum is computed in int arithmetic and widened at the end. The
result is correct for int16 inputs; it just reads as a precedence slip. Worth
pinning with a test during the move rather than silently "fixing".

### D1 — `_ActionBar` is the textbook shallow module

349 lines, 40 constructor parameters, and a body that is a flat `Wrap` of 33
buttons where each button is a mechanical projection of
(label, icon, colour, enabled-predicate, callback).

Deletion test: delete `_ActionBar` and the same 200 lines reappear inline in
`build`. It hides nothing. Its interface is *larger* than the behaviour behind it.

The cost is concrete: adding one debug button today means editing four places —
a `final VoidCallback onX` field, a `required this.onX` constructor entry, an
`onX: _handler` argument at the call site (`ble_debug_screen.dart:2271–2317`), and
the button widget itself.

**Proposal:** describe actions as data.

```
lib/features/debug/widgets/debug_action.dart      // DebugAction value type
lib/features/debug/widgets/debug_action_bar.dart  // DebugActionBar({required List<DebugAction>})
```

```dart
class DebugAction {
  const DebugAction({
    required this.label, required this.onTap,
    this.icon, this.color, this.enabled = true,
    this.style = DebugActionStyle.outlined,
    this.busy = false,
  });
}
```

Interface goes 40 params → 1. Adding a button becomes one list entry. The compact
`ButtonStyle`, the `Wrap` layout, and the per-style button construction move
behind the interface — that is the depth.

The same type also serves the AppBar tool strip (`_toolBtn`, lines 2172–2191, and
its 11 call sites at 2209–2227) as `DebugToolStrip(actions: [...])`. Two adapters
over one interface: a real seam by the rule, not a hypothetical one.

### D4 — the sync log formatters are pure functions that nothing can reach

Roughly 14 handlers between lines 763 and 1445 share one shape: call
`bandSyncServiceProvider.syncX()`, then emit 10–30 `_push(...)` lines shaping
`SyncStepResult.rawMap` / `rawList` into readable text.

`SyncStepResult` (`lib/core/sync/sync_results.dart:8`) is a plain value type with
no Flutter dependency, so all of that formatting is pure. Its own docstring says:

> `rawMap` / `rawList` carry the underlying BLE response so the debug screen can
> dump the band's payload verbatim.

The formatters are therefore the *only* consumer of that contract — and today
nothing pins it. ~450 lines of string surgery over band payloads, exercisable
only by tapping a button while connected to a ring.

**Proposal:** `lib/features/debug/sync_log_format.dart`

```dart
List<String> formatHrSync(SyncStepResult r);
List<String> formatSpo2Sync(SyncStepResult r);
List<String> formatSleepSync(SyncStepResult r);
List<String> formatStepsSync(SyncStepResult r);
List<String> formatStepBucketsSync(SyncStepResult r);
List<String> formatHrvSync(SyncStepResult r);
List<String> formatStressSync(SyncStepResult r);
List<String> formatBpSync(SyncStepResult r);
List<String> formatSyncRun(SyncRunResult r);   // periodic tick + Run All
String preview(Object? list, int max);         // was _preview, line 390
```

Each handler collapses to:

```dart
final res = await ref.read(bandSyncServiceProvider).syncHr(...);
for (final line in formatHrSync(res)) _push(line);
```

This is the house replay pattern and it comes almost free:
`test/sync_adapters_bp_test.dart` and `test/sync_adapters_sleep_test.dart`
already carry real captured payloads. The same fixtures feed the formatter tests.

`formatSyncRun` also de-duplicates the periodic-tick block (lines 323–348) against
`_runAllSyncs` (lines 1544–1554), which format the same `SyncRunResult` two
different ways today.

**Delete on the way through:** `ble_debug_screen.dart:1412` is
`ref.read(bpRepositoryProvider);` with the comment *"Touch the BP repo so the
analyzer doesn't drop the unused import."* That is a workaround for the exact
lint hazard described in §7. It and its import go when D4 lands.

### D3 — the capture buffer's alignment invariant is enforced by a comment

Ten parallel lists plus three counters and two timestamps
(`ble_debug_screen.dart:99–143`) are filled by a 50-line loop inside
`_attachListeners` (lines 264–298), and drained 700–2,300 lines away by
`_analyzePpg` and `_exportRawCaptureToClipboard`. The rule that all eight channel
lists stay 1:1 with `_ppgCountSeq` is stated only in a comment (lines 115–130) and
holds only because every list is appended inside one `if (c is num)` block. Any
future edit to that loop can break it silently.

**Proposal:** `lib/features/debug/ppg_capture_buffer.dart` (feature-local, mirroring
`bp_controller.dart`).

```dart
class PpgCaptureBuffer {
  void start();  void stop();  void addPacket(Map<String, dynamic> sample);
  int get packetCount;  int get greenZeroCount;  double? get fsHz;
  double get durationSec;
  List<int> get counts;  List<double> get greens;   // → PpgAnalysisService
  String toRawExport();                             // → clipboard
}
```

In-process, no I/O — merge and test through the interface directly. One test:
feed a synthetic packet list containing a `ppg_count` gap, a `green: 0` packet,
and a non-numeric `ppg_count`; assert every channel length matches, that
`greenZeroCount` counts the blank, and that the export header reports the right
`fs_hz` and channel-activity summary.

`_exportRrToClipboard` (lines 2501–2537) belongs with it — it is pure formatting
over `PpgAnalysisResult` and can be a top-level `String formatRrExport(PpgAnalysisResult)`.

## 5. Step-by-step plan

Ordering rules: **leaf before root**, **mechanical before semantic**, and each
step is one commit that leaves `flutter analyze` clean and `flutter test` green.
Mechanical moves and behaviour changes never share a commit, so any visual or
functional regression bisects to a single step.

### Part A — `settings_screen.dart` (safest first; do this part first to build confidence in the pattern)

| Step | Move | From → To | Δ lines | Risk |
|---|---|---|---|---|
| **S1** | `_kTermsText`, `_kPrivacyText` → `kTermsText`, `kPrivacyText` | 1633–1682 → `features/settings/legal_text.dart` | −50 | none |
| **S2** | 7 tile widgets, **verbatim**, made public | scattered → `features/settings/widgets/settings_tiles.dart` | −251 | none |
| **S3** | 3 presentational screens | `_ComingSoonScreen`, `_LegalTextScreen`, `_AboutScreen` + `_AboutTile` → `coming_soon_screen.dart`, `legal_text_screen.dart`, `about_screen.dart` | −178 | none |
| **S4** | `_IntegrationsScreen` | → `features/settings/integrations_screen.dart` | −142 | low |
| **S5** | `_GeneralSettingsScreen` | → `features/settings/general_settings_screen.dart` | −189 | low (raw prefs I/O moves as-is) |
| **S6** | `_SupportScreen` + `_SubmitTicketScreen` | → `support_screen.dart`, `submit_ticket_screen.dart` | −265 | low |
| **S7** | `_ProfileViewScreen` | → `features/settings/profile_view_screen.dart` | −696 | medium — has state + repo writes |
| **S8** | Profile edit dialogs | out of `profile_view_screen.dart` → `features/settings/widgets/profile_edit_dialogs.dart` | −~250 | medium — behaviour change, see below |
| **S9** | Unify the tiles | `settings_tiles.dart` → `SettingsTile` + `SettingsFaqTile` | −~150 | **visual** — needs eyeballing |

After S1–S7, `settings_screen.dart` is ~235 lines: the root `ListView` and
`_confirmLogOut`. That alone is the bulk of the win.

**S8 detail.** `_ProfileViewScreen` is ~350 lines of `showDialog` boilerplate
across nickname / DOB / gender / height / weight / credential / delete / CSV /
cache. Five small functions replace all of it:

```dart
Future<String?>  promptText(BuildContext, {required String title, String? initial, String? hint});
Future<double?>  promptNumber(BuildContext, {required String title, double? initial, required String suffix});
Future<T?>       promptChoice<T>(BuildContext, {required String title, required List<T> options, T? selected, required String Function(T) label});
Future<bool>     promptConfirm(BuildContext, {required String title, required String body, String yes, String no, bool destructive});
Future<bool>     promptDoubleConfirm(BuildContext, {required String title, required String body, required String secondTitle, required String secondBody});
```

Deep: five signatures hide the `AlertDialog` shell, `AppColors.surface`
background, destructive-button styling, and — the reason this is a behaviour
change — **controller lifecycle**. The settings dialogs dispose their
`TextEditingController`s correctly today, but the debug screen's two dialogs do
not: `_renameDevice` (`ble_debug_screen.dart:542`) and `_promptDayIndex`
(line 833) both allocate one and never dispose it. `_promptDayIndex` is called
from six handlers. Once these helpers exist, the debug screen uses them too and
the leak is fixed once, everywhere — the locality payoff.

**S9 detail.** The seven tiles are near-identical: `Container(surface, radius) >
ListTile(leading icon, title, subtitle, chevron, onTap)`. They differ on radius
(12 vs 14), margin (`EdgeInsets.only(bottom: 8)` vs none plus a
`SizedBox(height: 8)` at the call site), whether a subtitle exists, and the
trailing widget (chevron / value-then-chevron / nothing). Those differences look
like drift rather than design.

Collapsing all seven into one widget with nine optional parameters would produce
a *shallow* module — interface as complex as the implementation, which is the
thing to avoid. Two widgets is the right number:

- `SettingsTile` — `{icon, title, subtitle?, trailing?, onTap, style: plain|card, iconColor?}`.
  `trailing` defaults to a chevron; `_EditableProfileRow`'s value-on-the-right is
  just `trailing: Text(value)`; `_SettingsTile`'s bare root-list look is
  `style: plain`.
- `SettingsFaqTile` — the `ExpansionTile` (lines 1984–2022). Genuinely different
  behaviour; keep it separate.

This normalises radius and spacing to one value, so **it moves pixels**. That is
why it is last and standalone: with S2 already landed as a verbatim move, S9's
diff is small and any visual complaint bisects to exactly this commit.

**Not part of this plan, noted for the record.** `_GeneralSettingsScreen` writes
`unit_system` and `app_language` straight to `SharedPreferences`, and a grep shows
**nothing else in `lib/` reads either key** — the Imperial setting is inert; the
user can pick it and nothing changes. An `AppPreferences` service in
`core/services/` (matching the `_kSomethingKey` convention in
`entitlement_service.dart`, `scheduled_ppg_capture_service.dart`, etc.) is what
would make it consumable. But today that is a one-adapter seam, so it is a
*feature* decision, not a decomposition step. Same for `_ageFromDob`
(`settings_screen.dart:761`), which duplicates `BpController.ageFromDob`
(`bp_controller.dart:27`) — with different null handling (`int?` vs `int`
defaulting to 30), so it is not a straight de-dupe. Flagging, not folding in.

### Part B — `ble_debug_screen.dart`

| Step | Move | To | Δ lines | Risk |
|---|---|---|---|---|
| **D6** | `_LogEntry`, `_push`, `_copyLogToClipboard`, log `ListView`, `_CollapsibleSection` | `features/debug/debug_log_controller.dart` + `widgets/debug_log_view.dart`, `widgets/collapsible_section.dart` | −120 | low — but touches ~200 call sites, so it goes first |
| **D5** | Battery drain test: 4 methods, 2 prefs keys, 2 fields, `_BatteryTestPanel` | `features/debug/battery_drain_test_controller.dart` + `widgets/battery_test_panel.dart` | −233 | low — self-contained |
| **D1** | `_ActionBar`, `_toolBtn`, `_StatusPanel` | `widgets/debug_action.dart`, `widgets/debug_action_bar.dart`, `widgets/debug_status_panel.dart` | −470 | medium — 40 call-site args become a list |
| **D3** | 10 buffers + `_resetCaptureBuffers` + the `_attachListeners` loop + raw/R-R exports | `features/debug/ppg_capture_buffer.dart` | −165 | medium — invariant must be preserved exactly |
| **D4** | 14 sync-handler formatters + `_preview` | `features/debug/sync_log_format.dart` | −450 | medium — largest diff, but purely textual |
| **D2** | Fall Watch → analyzer + session; rewire `FallSweepService` | `core/processing/fall_window_analyzer.dart` + `core/services/fall_watch_session.dart` | −162 | **highest** — behaviour change (calibration rule), needs a test first |

D6 goes first because `_push` is the substrate every other step's diff touches;
moving it later would mean re-touching all of them. D2 goes last because it is
the only step that intentionally changes behaviour, and it should land on a file
that is already small enough to review.

After Part B, `ble_debug_screen.dart` is roughly 3,260 → ~1,300 lines: the state
class shrinks to stream wiring, session/device management, the `_computeScores`
and `_aggregate` diagnostic orchestration, and `build`.

**Explicitly out of scope for this pass:**

- `_computeScores` (lines 945–1111, 167 lines) and `_aggregate` (1588–1669).
  These orchestrate four services and log a running commentary that *is* the
  diagnostic output. Splitting orchestration from narration here would produce
  two shallow modules; the formatter treatment that works for D4 does not apply
  because there is no single result value to format. Leave until the scoring
  path stabilises.
- The scan/connect/rename/binding block (lines 469–761). It contains real
  product logic — the MAC-binding hard reject and first-pair confirmation — and
  `pairing_screen.dart:14` says it "Mirrors the scan/connect/ensureDevice path
  from the BLE debug screen", so there are already two copies. Consolidating them
  into a `DeviceBindingController` is worthwhile but is a *production* change
  with a real blast radius, not screen decomposition. It deserves its own plan.

## 6. Extractions considered and rejected

| Rejected | Why |
|---|---|
| Split `_ActionBar` into `HrActions`, `Spo2Actions`, `BpActions`… | Multiplies shallow modules. With D1's data description, grouping is a list section, not a class. |
| A `DebugCommand` registry with dynamic dispatch | Over-abstraction. A `List<DebugAction>` is legible and greppable; a registry is not. |
| One class per sync command (16 `SyncCommand` subclasses) | 16 shallow modules replacing 16 methods. The win is that the *formatting* is pure, not that the orchestration is wrapped. |
| One `SettingsTile` with 9 optional params | Interface as complex as the implementation. Two widgets, not one. |
| `_ProfileViewScreen` → `widgets/` | It is a route destination. Siblings match `monitoring_screen.dart` and friends. |
| A `Prefs` façade over all `SharedPreferences` use | Each existing service already owns its own `_kKey` constants; a façade would be one adapter over nine unrelated concerns. |
| Rewriting `BleDebugScreen` as stateless + `StateNotifier` | Large blast radius, no test win beyond what the targeted controllers already give, and every provider here is hand-written by convention. |
| Extracting `_ensurePermissions` (lines 422–467) | 45 lines, one caller, platform-branching that reads fine in place. Deletion test says it is a pass-through. |

## 7. Keeping `flutter analyze` clean at every step

Two lints will bite on every single move under `package:flutter_lints`:

- **`unused_element`** — moving a private class out without deleting the original
  declaration leaves a dead private symbol behind.
- **`unused_import`** — removing the last user of a symbol strands its import.
  `ble_debug_screen.dart` has 35 imports; D4 alone drops several.

So the mechanical rule for each commit: **move the declaration, delete the
original, prune imports at both ends, then analyze.** Never leave a duplicate
"until the next step".

Per-step verification:

```bash
flutter analyze          # must print "No issues found!"
flutter test             # 243 tests across 28 files — must stay green
```

Neither needs the dart-define; only `run` and `build` do:

```bash
flutter run --dart-define-from-file=hlth.env.json
```

Steps that touch rendering (S3–S7, S9, D1, D5, D6) need a manual pass over the
affected route with the app running. S9 in particular needs a side-by-side look
at Settings → each subscreen, since it normalises corner radius and spacing.

## 8. New test files this unlocks

None of these exist today. All use real doubles per `CLAUDE.md` — no mocking
library.

| File | Covers | Pattern |
|---|---|---|
| `test/fall_window_analyzer_test.dart` | median 1 g calibration, milli-g rescale, minimum-sample gate, impact-during-calibration | pure function |
| `test/ppg_capture_buffer_test.dart` | 8-channel 1:1 alignment, `ppg_count` gaps, `green: 0` accounting, `fsHz`, export header | pure, synthetic packets |
| `test/sync_log_format_test.dart` | every `format*Sync` against captured band payloads | replay — reuses `sync_adapters_*_test.dart` fixtures |
| `test/battery_drain_test_controller_test.dart` | cadence persistence + cold-start re-apply, baseline insert | `NativeDatabase.memory()` + `SharedPreferences.setMockInitialValues` |

The `test/bp_controller_formulas_test.dart` precedent already shows the shape for
testing an extracted controller's pure parts.

## 9. Expected end state

| File | Before | After |
|---|---|---|
| `lib/features/settings/settings_screen.dart` | 2,022 | ~235 |
| `lib/features/debug/ble_debug_screen.dart` | 3,260 | ~1,300 |
| New files | — | 8 under `features/settings/`, 4 under `features/settings/widgets/`, 3 under `features/debug/`, 5 under `features/debug/widgets/`, 2 under `core/` |
| Largest remaining feature file | 3,260 | `blood_pressure_screen.dart` at 1,924 (next candidate) |
| Test files | 28 | 32 |

The headline is not the line count. It is that four pieces of logic that can
currently only be exercised by a human wearing a ring — fall calibration, PPG
channel alignment, band-payload formatting, and battery-cadence persistence —
become things `flutter test` can check, and that the debug screen stops
disagreeing with production about what counts as a fall.
