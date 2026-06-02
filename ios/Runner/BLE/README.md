# iOS Native BLE Layer

Bridges CoreBluetooth + `QCBandSDK.framework` to the Flutter `MethodChannel`
`com.hlth.hlth_app/ble` and event channels `com.hlth.hlth_app/ppg_stream`
and `com.hlth.hlth_app/accel_stream`.

## Required Xcode setup (one-time, not automatable from Flutter CLI)

1. Open `ios/Runner.xcworkspace` in Xcode.
2. Select the **Runner** target → **General** → **Frameworks, Libraries, and
   Embedded Content** → drag in `ios/Frameworks/QCBandSDK.framework`. Set it
   to **Embed & Sign**.
3. Build Settings → **Framework Search Paths** → add `$(PROJECT_DIR)/Frameworks`.
4. Build Settings → **Other Linker Flags** → add `-ObjC` if not present.
5. The bridging header `Runner-Bridging-Header.h` already exists — make sure
   it imports `<QCBandSDK/QCBandSDK.h>` (the wrapper imports `QCBandSDK` as a
   Swift module; if the framework ships a `module.modulemap` you can skip the
   bridging header entry).
6. Set deployment target to **iOS 13+** (CoreBluetooth background mode needs
   this).

## Reference

The demo app at
`QWatchPro_iOS_SDK_V1.0.0_20260326/QCBandSDKDemo/QCBandSDKDemo/` shows how
to drive `QCSDKManager` end-to-end (scan → bind → measure → query history).
Use it as the source of truth for callback payload shapes.
