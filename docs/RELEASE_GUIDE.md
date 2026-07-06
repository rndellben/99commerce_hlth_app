# Release Guide

Publishing `hlth_app` to Google Play and the App Store. Read
[BUILD_GUIDE.md](BUILD_GUIDE.md) first.

> ⚠️ **Current state:** the project builds and runs on devices, but **production
> signing is not fully configured** (see the Android gap below). Treat this as
> the target process; the marked items must be set up before a real store
> submission.

## Versioning

Single source of truth: `pubspec.yaml` → `version: 1.0.0+1`
(`<marketing>+<build>`). Flutter maps `+build` to Android `versionCode` and iOS
`CFBundleVersion`. **Bump the build number on every store upload** — stores
reject duplicate build numbers.

---

## Android — Google Play

### 1. Signing (⚠️ NOT YET CONFIGURED)

`android/app/build.gradle.kts:40` currently sets
`release { signingConfig = signingConfigs.getByName("debug") }` — release builds
are signed with the **debug** key, which **Play will reject**. To fix:

1. Create an upload keystore:
   ```bash
   keytool -genkey -v -keystore ~/hlth-upload.jks -keyalg RSA -keysize 2048 \
     -validity 10000 -alias hlth-upload
   ```
2. Add `android/key.properties` (git-ignored):
   ```
   storeFile=/abs/path/hlth-upload.jks
   storePassword=…
   keyAlias=hlth-upload
   keyPassword=…
   ```
3. In `build.gradle.kts`, load `key.properties`, declare a `release`
   `signingConfig` from it, and point `buildTypes.release.signingConfig` at it.
4. Enroll in **Play App Signing** (Google holds the app-signing key; you keep the
   upload key).

### 2. Build the bundle

```bash
flutter build appbundle --release --dart-define-from-file=hlth.env.json
# → build/app/outputs/bundle/release/app-release.aab
```

### 3. Play Console

- Create the app (package `com.hlth.hlth_app`), complete the store listing,
  content rating, data-safety, and privacy policy.
- **Health data disclosures:** the app collects HR/HRV/SpO2/sleep/BP — declare
  these in the Data safety form and honor the "wellness, not medical device"
  framing (see the regulatory-language guide).
- **Permissions:** `BLUETOOTH_SCAN`/`BLUETOOTH_CONNECT` (+ location for legacy
  scan) require a justification in the console.
- Upload the AAB to Internal testing → Closed → Production.

### 4. minSdk note

minSdk is **26** (QRing SDK requirement) — devices below Android 8.0 are
excluded automatically. Native libs ship arm64-v8a + armeabi-v7a (no x86).

---

## iOS — App Store / TestFlight

### 1. Signing & identifiers

- Apple Developer account + team. Bundle id `com.hlth.hlthApp` (RunnerTests:
  `com.hlth.hlthApp.RunnerTests`).
- Register the App ID, create Distribution certificate + App Store provisioning
  profile (or use Xcode **Automatically manage signing** with your Team).
- `Info.plist`: `NSBluetoothAlwaysUsageDescription` is mandatory (BLE), plus any
  background BLE modes if state restoration is enabled.

### 2. Bake env, then archive

```bash
flutter build ipa --release --dart-define-from-file=hlth.env.json
# or: flutter build ios --config-only … ; then Xcode → Product → Archive
```

### 3. Upload

- **Xcode Organizer** → Distribute App → App Store Connect, **or** `xcrun
  altool`/Transporter with the generated IPA
  (`build/ios/ipa/hlth_app.ipa`).
- App Store Connect: create the app record, fill privacy nutrition labels
  (health data), attach the build to **TestFlight** for internal testing, then
  submit for review.

### 4. Framework caveat

`QCBandSDK.framework` is a **static arm64** framework linked "Do Not Embed."
It must **not** be embedded/copied into the app bundle (that breaks archiving).
Device/arm64 only — App Store builds are arm64 so this is fine.

---

## Release checklist

- [ ] Bump `version:` build number.
- [ ] `flutter analyze` clean; `flutter test` green (minus the known
      `widget_test.dart` platform-channel case).
- [ ] `hlth.env.json` points at the **production** Supabase project + anon key.
- [ ] Android: real upload keystore + `key.properties` wired (⚠️ pending).
- [ ] iOS: distribution signing + `NSBluetoothAlwaysUsageDescription` present.
- [ ] Smoke test on a physical device with the ring: pair → sync → scores render.
- [ ] Data-safety / privacy disclosures updated for health metrics.

## Known pre-release gaps

1. **Android production signing** — not configured (debug key fallback).
2. **Cloud restore** — Supabase sync is push-only; a fresh install has no
   down-restore path (data-loss on device change). Not blocking, but flag to
   users.
3. **Background reliability** — nightly captures depend on the periodic sync
   tick firing under OS background/Doze constraints; validate on target devices.

See [PROJECT_DECISIONS.md](PROJECT_DECISIONS.md) for the rationale behind these.
