# Build Guide

Clone-to-run for `hlth_app`. A physical H59 ring is required for BLE features
(the SDKs don't work on simulators/emulators for band I/O).

## Prerequisites

| Tool | Version |
|---|---|
| Flutter | stable channel, Dart SDK **^3.8.1** |
| Android | Android Studio + SDK; **minSdk 26** (QRing SDK requires Android 8.0); JDK 17 |
| iOS | Xcode (26.x used here), CocoaPods, an Apple Developer account for device runs |
| Ruby | only if manipulating the Xcode project programmatically (`xcodeproj` gem) |

## 1. Dependencies & codegen

```bash
cd 99commerce_hlth_app
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # Drift + Freezed codegen
```

Run `build_runner` again after any change to Drift tables (`lib/core/database/tables.dart`),
`@freezed` models, or `enums.dart`.

## 2. Environment config (Supabase)

The app reads Supabase creds via **`--dart-define-from-file`**. Copy the example
and fill it in:

```bash
cp hlth.env.example.json hlth.env.json
```

```json
{ "SUPABASE_URL": "https://<project>.supabase.co",
  "SUPABASE_ANON_KEY": "<anon key>",
  "FLAVOR": "dev" }
```

`hlth.env.json` is git-ignored. **Missing values crash at startup** (`Missing
SUPABASE_URL`). Every run/build command must pass
`--dart-define-from-file=hlth.env.json`.

## 3. Run locally

```bash
# Android (physical device with the ring paired in system Bluetooth)
flutter run --dart-define-from-file=hlth.env.json

# iOS — env must be baked into Generated.xcconfig before opening Xcode:
flutter build ios --config-only --dart-define-from-file=hlth.env.json
open ios/Runner.xcworkspace     # then Run the "Runner" target on a device
```

> **iOS via Xcode:** open `Runner.xcworkspace` (not `.xcodeproj`), select the
> **Runner** target + your device, set your signing Team, Run. If you `flutter
> run` without the config-only step first, Supabase env will be missing.

## 4. Native SDK wiring (already committed, but for reference)

- **Android:** `qring_sdk_1.0.0.17.aar` in `android/app/libs/`, referenced by
  `build.gradle.kts:47`. Core-library desugaring enabled for minSdk 26.
- **iOS:** `QCBandSDK.framework` in `ios/Frameworks/`, linked to the Runner
  target as **Do Not Embed** (static arm64 framework); BLE Swift files in the
  target's **Compile Sources**. **Required per the vendor guide:** add `-ObjC`
  to Other Linker Flags, exclude the **arm64 simulator** arch, and add **both**
  `NSBluetoothAlwaysUsageDescription` + `NSBluetoothPeripheralUsageDescription`
  to `Info.plist`. Full detail in [IOS_SDK_REFERENCE.md](IOS_SDK_REFERENCE.md).

## 5. Debugging

- **BLE Debug screen** (in-app) — scan/connect, per-metric sync buttons,
  "Enable Mon" (scheduled monitoring), "Scores" (compute + log HRV window/sample
  counts), "Rec Hist", R-R, battery drain test. Primary field-diagnostics tool.
- **Android:** `adb logcat -s HlthBLE` — bridge logs (bootstrap capabilities,
  monitoring read-backs, sync results).
- **Kotlin changes need a full `flutter run`** — hot reload/restart won't pick
  up native (`BleManager.kt`) edits. Dart changes hot-restart fine.

## 6. Tests

```bash
flutter test                                   # full suite
flutter test test/vo2max_estimation_test.dart  # a single file
flutter analyze                                # static analysis (keep clean)
```

Tests use **dependency-injected fakes**, not a real DB or device (see the
`vo2max_service_test.dart` pattern). Pure engines (`core/scoring/*`) are tested
against hand-computed values. One known-failing test: `widget_test.dart` pumps
the full app and needs platform channels unavailable under `flutter test` —
pre-existing, unrelated to feature work.

## 7. Release builds

```bash
flutter build appbundle --dart-define-from-file=hlth.env.json   # Android AAB
flutter build ipa       --dart-define-from-file=hlth.env.json   # iOS IPA
```

See [RELEASE_GUIDE.md](RELEASE_GUIDE.md) — **note: Android release signing is
not yet configured** (currently falls back to the debug key).

## Project coordinates

| | |
|---|---|
| App name | `hlth_app` — "HLTH Smartband Companion App" |
| Version | `1.0.0+1` (bump in `pubspec.yaml`) |
| Android applicationId / namespace | `com.hlth.hlth_app` (minSdk 26) |
| iOS bundle id | `com.hlth.hlthApp` |
