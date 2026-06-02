package com.hlth.hlth_app.ble

import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.oudmon.ble.base.bluetooth.BleOperateManager
import com.oudmon.ble.base.bluetooth.ListenerKey
import com.oudmon.ble.base.communication.CommandHandle
import com.oudmon.ble.base.communication.Constants
import com.oudmon.ble.base.communication.ICommandResponse
import com.oudmon.ble.base.communication.ILargeDataSleepResponse
import com.oudmon.ble.base.communication.LargeDataHandler
import com.oudmon.ble.base.communication.bigData.BloodOxygenEntity
import com.oudmon.ble.base.communication.bigData.IBloodOxygenCallback
import com.oudmon.ble.base.communication.entity.BleStepDetails
import com.oudmon.ble.base.communication.req.BloodOxygenSettingReq
import com.oudmon.ble.base.communication.req.HRVReq
import com.oudmon.ble.base.communication.req.HeartRateSettingReq
import com.oudmon.ble.base.communication.req.HrvSettingReq
import com.oudmon.ble.base.communication.req.ReadDetailSportDataReq
import com.oudmon.ble.base.communication.req.ReadHeartRateReq
import com.oudmon.ble.base.communication.req.SetTimeReq
import com.oudmon.ble.base.communication.req.SimpleKeyReq
import com.oudmon.ble.base.communication.responseImpl.DeviceNotifyListener
import com.oudmon.ble.base.communication.rsp.BloodOxygenSettingRsp
import com.oudmon.ble.base.communication.rsp.BpDataRsp
import com.oudmon.ble.base.communication.rsp.DeviceNotifyRsp
import com.oudmon.ble.base.communication.rsp.HRVRsp
import com.oudmon.ble.base.communication.rsp.HRVSettingRsp
import com.oudmon.ble.base.communication.rsp.HeartRateSettingRsp
import com.oudmon.ble.base.communication.rsp.ReadDetailSportDataRsp
import com.oudmon.ble.base.communication.rsp.ReadHeartRateRsp
import com.oudmon.ble.base.communication.rsp.SetTimeRsp
import com.oudmon.ble.base.bean.SleepDisplay
import com.oudmon.ble.base.communication.rsp.StopHeartRateRsp
import com.oudmon.ble.base.communication.rsp.TodaySportDataRsp
import com.oudmon.ble.base.scan.BleScannerHelper
import com.oudmon.ble.base.scan.ScanRecord
import com.oudmon.ble.base.scan.ScanWrapperCallback
import com.hlth.hlth_app.HlthApplication
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Calendar
import java.util.TimeZone

/**
 * Bridges the QRing Android SDK (Oudmon BLE library) to the Flutter
 * MethodChannel `com.hlth.hlth_app/ble` and event channels for streaming.
 *
 * Architecture (confirmed by sdk_ring.pdf + H59 hardware testing 2026-05-22):
 *   - H59 ring does NOT support on-demand HR/SpO2 measurement
 *   - All data is collected on the band's schedule and synced via Data Sync
 *     commands (`ReadHeartRateReq(nowTime)`, `LargeDataHandler.syncBloodOxygen()`,
 *     etc.)
 *   - First-pair flow must call `enableHealthMonitoring()` to write
 *     HeartRateSettingReq with isEnable=true + an interval, otherwise the
 *     band stays dormant and Data Sync returns empty arrays
 *   - Band proactively pushes new readings via `DeviceNotifyListener`; we
 *     forward those to Dart so the UI can update in near-real-time
 */
class BleManager(
    private val context: Context,
    private val activity: Activity?
) : MethodChannel.MethodCallHandler {

    companion object {
        // Channel names match hlth-ble-platform-channel.md §1.
        // Raw PPG samples are emitted on the realtime stream.
        private const val METHOD_CHANNEL = "hlth/ble"
        private const val PPG_EVENT_CHANNEL = "hlth/realtime_stream"
        private const val ACCEL_EVENT_CHANNEL = "hlth/realtime_stream_accel"
        private const val SCAN_TIMEOUT_MS = 10_000L
        // HLT-11: periodic sync cadence (30 min). Long enough that battery
        // cost is negligible on top of the always-on BLE connection; short
        // enough to keep home-screen cards fresh and to make the band's
        // 30-min HRV slot resolution observable without manual taps.
        private const val PERIODIC_SYNC_INTERVAL_MS = 30L * 60L * 1000L
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    // Per-session flag — flips true on first connect event, back to false
    // on disconnect. Prevents bootstrapBandAfterConnect from firing
    // repeatedly when onConnectionChange triggers multiple times.
    private var hasBootstrapped = false
    // Currently-connected device name. Captured from the SDK's
    // BluetoothReceiver onConnectionChange callback so the foreground
    // service notification can show "HLTH — H59 Ring" instead of "HLTH".
    private var connectedDeviceName: String = ""
    // HLT-9: debounce floor for the realtime-HR trigger-then-sync flow.
    // The band fires dataType=1 ("new HR data exists") after each scheduled
    // measurement; we poke the band for the latest reading, but cap the
    // sync rate at one per 5 sec so we don't hammer the BLE channel if
    // notifications batch.
    private var lastRealtimeHrSyncMs: Long = 0L

    // HLT-11: periodic sync tick. Posts a Runnable on the main looper every
    // PERIODIC_SYNC_INTERVAL_MS while connected. The runnable just signals
    // Dart via `onPeriodicSyncTick` — no business logic lives natively.
    // Dart's PeriodicSyncCoordinator owns the actual sync orchestration.
    //
    // Lives in BleManager (not BleForegroundService) for two reasons:
    //   1. Direct access to `methodChannel` — no IPC needed
    //   2. The FG service keeps the process alive, so this Handler keeps
    //      firing even when the activity is destroyed
    private val periodicSyncRunnable = object : Runnable {
        override fun run() {
            try {
                methodChannel.invokeMethod("onPeriodicSyncTick", null)
                Log.i("HlthBLE", "periodic sync tick → Dart")
            } catch (e: Exception) {
                Log.w("HlthBLE", "periodic sync tick failed: ${e.message}")
            }
            // Re-arm
            mainHandler.postDelayed(this, PERIODIC_SYNC_INTERVAL_MS)
        }
    }
    private lateinit var methodChannel: MethodChannel
    @Suppress("unused")
    private var ppgEventSink: EventChannel.EventSink? = null
    @Suppress("unused")
    private var accelEventSink: EventChannel.EventSink? = null

    private val discoveredDevices = mutableMapOf<String, ScanEntry>()
    private var pendingScanResult: MethodChannel.Result? = null

    private data class ScanEntry(val name: String, val address: String, val rssi: Int)

    fun register(flutterEngine: FlutterEngine) {
        methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            METHOD_CHANNEL
        )
        methodChannel.setMethodCallHandler(this)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, PPG_EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    ppgEventSink = events
                }
                override fun onCancel(arguments: Any?) { ppgEventSink = null }
            })

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, ACCEL_EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    accelEventSink = events
                }
                override fun onCancel(arguments: Any?) { accelEventSink = null }
            })

        // Listen for proactive notifications from the band (real-time HR,
        // BP, SpO2, step updates, etc.). Per the SDK docs, ListenerKey.All=7
        // subscribes to every data-type the band reports.
        BleOperateManager.getInstance().addOutDeviceListener(
            ListenerKey.All,
            deviceNotifyListener
        )

        // Forward connection state changes from the SDK-level receiver
        // to Dart so the UI can react to drops/reconnects in real time.
        HlthApplication.bluetoothReceiver.onConnectionChange = { connected, name ->
            mainHandler.post {
                methodChannel.invokeMethod(
                    if (connected) "onConnected" else "onDisconnect",
                    mapOf("deviceName" to (name ?: ""))
                )
            }
            // Bootstrap the band after connection (sdk_ring.pdf §2.3.1).
            // Debounced — HlthBluetoothReceiver already fires CMD_BIND_SUCCESS
            // on onServiceDiscovered, and `onConnectionChange` can fire 2-3×
            // per real connection (BLE link up, services discovered, MTU set).
            // We only need to run SetTimeReq once per session.
            if (connected) {
                connectedDeviceName = name ?: ""
                // Promote the process to foreground so Android doesn't reap
                // it while the screen is off (HLT-10). The service stays up
                // until disconnect.
                BleForegroundService.start(context, connectedDeviceName)
                if (!hasBootstrapped) {
                    hasBootstrapped = true
                    mainHandler.postDelayed({ bootstrapBandAfterConnect() }, 1500)
                    // HLT-11: kick off the periodic sync schedule. First tick
                    // fires PERIODIC_SYNC_INTERVAL_MS after connect (not
                    // immediately — Dart side handles startup sync on its own
                    // when it wants to).
                    mainHandler.postDelayed(
                        periodicSyncRunnable,
                        PERIODIC_SYNC_INTERVAL_MS
                    )
                    Log.i("HlthBLE", "periodic sync scheduled (every ${PERIODIC_SYNC_INTERVAL_MS / 60000} min)")
                }
            } else {
                hasBootstrapped = false
                connectedDeviceName = ""
                BleForegroundService.stop(context)
                // HLT-11: cancel periodic sync — no point firing ticks
                // while disconnected.
                mainHandler.removeCallbacks(periodicSyncRunnable)
            }
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        // Method names follow hlth-ble-platform-channel.md §3 canonical
        // catalogue. Underlying SDK calls and response shapes are
        // unchanged — Dart adapter layer reshapes to canonical envelope.
        when (call.method) {
            // §3.2 Discovery & connection
            "startScan" -> startScan(result)
            "stopScan" -> stopScan(result)
            "connect" -> connect(call.argument<String>("deviceId"), result)
            "disconnect" -> disconnect(result)

            // §3.5 Scheduled monitoring config — single first-pair entry point
            // until we split into per-metric setScheduledXxx in step 5+.
            "setScheduledMonitoring" -> enableHealthMonitoring(
                hrInterval = call.argument<Int>("hrInterval") ?: 10,
                startInterval = call.argument<Int>("startInterval") ?: 5,
                spo2Interval = call.argument<Int>("spo2Interval") ?: 60,
                hrvInterval = call.argument<Int>("hrvInterval") ?: 30,
                result = result
            )
            "getScheduledHr" -> readHeartRateSettings(result)

            // §3.7 History fetch
            "getHrHistory" -> syncHeartRate(result)
            "getSpO2History" -> syncSpO2(result)
            "getHrvHistory" -> syncHRV(call.argument<Int>("dayOffset") ?: 0, result)
            "getBpHistory" -> syncBloodPressure(result)
            "getSleepHistory" -> syncSleep(call.argument<Int>("dayOffset") ?: 0, result)
            "getDailyTotals" -> syncSteps(result)
            "getStepBucketHistory" -> syncStepsDetail(call.argument<Int>("dayOffset") ?: 0, result)

            // §3.6 Raw PPG measurement
            "startMeasureHrRaw" -> startPpgRawCapture(
                seconds = call.argument<Int>("duration_sec")
                    ?: call.argument<Int>("seconds") ?: 30,
                result = result
            )
            "stopMeasure" -> stopPpgRawCapture(result)

            else -> result.notImplemented()
        }
    }

    // ──────────────────────────────────────────────────────────────────────
    // Scan + connect
    // ──────────────────────────────────────────────────────────────────────

    private fun startScan(result: MethodChannel.Result) {
        val act = activity ?: run {
            result.error("NO_ACTIVITY", "Activity not attached", null)
            return
        }
        discoveredDevices.clear()
        pendingScanResult = result

        // Force-release any stuck SDK state before scanning. If the user
        // disconnected via the band going out of range / idle drop, the
        // SDK may still be in a half-bound "trying to reconnect" state
        // which prevents the band from advertising. Hard release first.
        try {
            BleOperateManager.getInstance().setNeedConnect(false)
            BleOperateManager.getInstance().unBindDevice()
        } catch (_: Exception) {}

        Log.i("HlthBLE", "scan: starting (SDK helper + direct BluetoothLeScanner fallback)")

        // Path 1: SDK's helper (works for QRing demo on this device)
        BleScannerHelper.getInstance().reSetCallback()
        BleScannerHelper.getInstance().scanDevice(act, null, scanCallback)

        // Path 2: Modern Android BLE scan in parallel. This is what
        // Settings → Bluetooth uses internally. It works without location
        // on Android 12+ thanks to our `neverForLocation` manifest flag,
        // and bypasses any quirk in the SDK's legacy LeScanCallback path.
        startDirectAndroidScan()

        mainHandler.postDelayed({
            if (pendingScanResult != null) {
                stopAllScans(act)
                val devices = discoveredDevices.values.map {
                    mapOf("id" to it.address, "name" to it.name, "rssi" to it.rssi)
                }
                Log.i("HlthBLE", "scan: complete, ${devices.size} device(s)")
                pendingScanResult?.success(devices)
                pendingScanResult = null
            }
        }, SCAN_TIMEOUT_MS)
    }

    private fun stopScan(result: MethodChannel.Result) {
        activity?.let { stopAllScans(it) }
        result.success(null)
    }

    private fun stopAllScans(act: Activity) {
        try { BleScannerHelper.getInstance().stopScan(act) } catch (_: Exception) {}
        try {
            val adapter = (context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager)?.adapter
            adapter?.bluetoothLeScanner?.stopScan(directScanCallback)
        } catch (_: Exception) {}
    }

    private fun startDirectAndroidScan() {
        try {
            val adapter: BluetoothAdapter? =
                (context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager)?.adapter
            if (adapter == null || !adapter.isEnabled) {
                Log.w("HlthBLE", "direct scan: bluetooth adapter null or disabled")
                return
            }
            val scanner = adapter.bluetoothLeScanner
            if (scanner == null) {
                Log.w("HlthBLE", "direct scan: bluetoothLeScanner is null")
                return
            }
            val settings = ScanSettings.Builder()
                .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
                .build()
            scanner.startScan(null, settings, directScanCallback)
            Log.i("HlthBLE", "direct scan: started")
        } catch (e: SecurityException) {
            Log.e("HlthBLE", "direct scan: SecurityException — permissions not granted at runtime", e)
        } catch (e: Exception) {
            Log.e("HlthBLE", "direct scan: failed", e)
        }
    }

    private val directScanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult?) {
            val device = result?.device ?: return
            val name = try { device.name } catch (_: SecurityException) { null }
            val address = device.address ?: return
            Log.d("HlthBLE", "direct scan hit: addr=$address name=$name rssi=${result.rssi}")
            // Capture even nameless devices — H59 may not always include name
            // in every advertisement packet. Display address as fallback name.
            discoveredDevices[address] = ScanEntry(
                name = name ?: address,
                address = address,
                rssi = result.rssi
            )
        }
        override fun onScanFailed(errorCode: Int) {
            Log.e("HlthBLE", "direct scan: onScanFailed errorCode=$errorCode")
        }
    }

    private val scanCallback = object : ScanWrapperCallback {
        override fun onStart() {
            Log.i("HlthBLE", "SDK scan: onStart")
        }
        override fun onStop() {
            Log.i("HlthBLE", "SDK scan: onStop")
        }
        override fun onLeScan(device: BluetoothDevice?, rssi: Int, scanRecord: ByteArray?) {
            if (device == null) return
            val name = try { device.name } catch (_: SecurityException) { null }
            Log.d("HlthBLE", "SDK scan hit: addr=${device.address} name=$name rssi=$rssi")
            // Don't filter on name — capture everything so H59 (which may
            // advertise without a name in some packets) still appears.
            discoveredDevices[device.address] = ScanEntry(
                name = name ?: device.address,
                address = device.address,
                rssi = rssi
            )
        }
        override fun onScanFailed(errorCode: Int) {
            Log.e("HlthBLE", "SDK scan: onScanFailed errorCode=$errorCode")
            pendingScanResult?.error("SCAN_FAILED", "errorCode=$errorCode", null)
            pendingScanResult = null
        }
        override fun onParsedData(device: BluetoothDevice?, scanRecord: ScanRecord?) {}
        override fun onBatchScanResults(results: MutableList<ScanResult>?) {}
    }

    private fun connect(deviceId: String?, result: MethodChannel.Result) {
        if (deviceId == null) {
            result.error("BAD_ARGS", "deviceId required", null)
            return
        }
        try {
            // Tell the SDK to maintain connection across transient drops.
            // The QRing demo flips this true before connectDirectly.
            BleOperateManager.getInstance().setNeedConnect(true)
            BleOperateManager.getInstance().connectDirectly(deviceId)
            // The SDK confirms connection via EventBus BluetoothEvent. We
            // resolve optimistically here and forward the real state change
            // through onConnectionStateChange invokeMethod once wired.
            result.success(null)
        } catch (e: Exception) {
            Log.e("HlthBLE", "connect failed", e)
            result.error("CONNECT_FAILED", e.message, null)
        }
    }

    /**
     * Post-connect bootstrap required by the QRing firmware (per
     * sdk_ring.pdf §2.3.1 + §2.3.2).
     *
     *  1. `CMD_BIND_SUCCESS` — bind handshake. Without this the band silently
     *     rejects every subsequent monitoring write (HeartRateSettingReq /
     *     BloodOxygenSettingReq / HrvSettingReq all return isEnable=false).
     *  2. `SetTimeReq(0)` — sets device time AND returns the device's
     *     capability bitmap (SetTimeRsp.mSupport*). Critical to know
     *     whether H59 firmware actually supports HRV — `mSupportHrv` tells
     *     us. If false, HRV will never work no matter what we send.
     *
     * Both are fire-and-forget — failures are logged to logcat and the
     * connection still proceeds.
     */
    private fun bootstrapBandAfterConnect() {
        try {
            CommandHandle.getInstance().executeReqCmdNoCallback(
                SimpleKeyReq(Constants.CMD_BIND_SUCCESS)
            )
            Log.i("HlthBLE", "bootstrap: CMD_BIND_SUCCESS sent")
        } catch (e: Exception) {
            Log.w("HlthBLE", "bootstrap: bind failed: ${e.message}")
        }

        // 800ms gap — give the band time to process the bind before pushing
        // the next command on the same MTU.
        mainHandler.postDelayed({
            try {
                CommandHandle.getInstance().executeReqCmd(
                    SetTimeReq(0),
                    ICommandResponse<SetTimeRsp> { rsp ->
                        Log.i("HlthBLE", "bootstrap: time set, capabilities ↓")
                        Log.i("HlthBLE", "  mSupportHrv:           ${rsp.mSupportHrv}")
                        Log.i("HlthBLE", "  mSupportBloodOxygen:   ${rsp.mSupportBloodOxygen}")
                        Log.i("HlthBLE", "  mSupportBloodPressure: ${rsp.mSupportBloodPressure}")
                        Log.i("HlthBLE", "  mSupportTemperature:   ${rsp.mSupportTemperature}")
                        Log.i("HlthBLE", "  mNewSleepProtocol:     ${rsp.mNewSleepProtocol}")
                        Log.i("HlthBLE", "  mSupportMenstruation:  ${rsp.mSupportMenstruation}")
                        Log.i("HlthBLE", "  mSupportFeature:       ${rsp.mSupportFeature}")
                    }
                )
            } catch (e: Exception) {
                Log.w("HlthBLE", "bootstrap: SetTimeReq failed: ${e.message}")
            }
        }, 800)
    }

    private fun disconnect(result: MethodChannel.Result) {
        try {
            // Hard release: tell the SDK to stop auto-reconnecting BEFORE
            // unbinding, otherwise it immediately re-bonds and the band
            // stays in "connected" state from its own perspective (which
            // prevents it from advertising for the next scan).
            BleOperateManager.getInstance().setNeedConnect(false)
            BleOperateManager.getInstance().unBindDevice()
            Log.i("HlthBLE", "disconnect: hard release (needConnect=false + unBind)")
            result.success(null)
        } catch (e: Exception) {
            Log.e("HlthBLE", "disconnect failed", e)
            result.error("DISCONNECT_FAILED", e.message, null)
        }
    }

    // ──────────────────────────────────────────────────────────────────────
    // Health monitoring config (first-pair flow)
    // ──────────────────────────────────────────────────────────────────────

    /**
     * Writes all the scheduled-monitoring switches. On H59 this is the only
     * way to make the band actually measure — without these writes, the
     * sync APIs return empty arrays even when the band is worn.
     *
     * Defaults match what QWatch Pro writes when its "Heart Rate Detection"
     * toggle is enabled.
     */
    // ──────────────────────────────────────────────────────────────────────
    // Raw PPG streaming (user-triggered measurement)
    //
    // `manualModeHeartRateRawData(callback, seconds, stop)` starts an active
    // band measurement that streams `StopHeartRateRsp` packets back. Each
    // packet contains a green/red/IR PPG sample, accelerometer XYZ, and the
    // band's current best-effort heart/RRI/HRV values. Packet rate is
    // device-dependent (typically tens per second during active measurement).
    //
    // We forward every packet to Dart via the ppg_stream EventChannel as a
    // single-element list (matching the existing rawPpgEvent shape) so the
    // PPG packet counter in the debug screen ticks up.
    // ──────────────────────────────────────────────────────────────────────
    private fun startPpgRawCapture(seconds: Int, result: MethodChannel.Result) {
        try {
            BleOperateManager.getInstance().manualModeHeartRateRawData(
                object : ICommandResponse<StopHeartRateRsp> {
                    override fun onDataResponse(rsp: StopHeartRateRsp) {
                        if (rsp.errCode != 0x00.toByte()) {
                            Log.w("HlthBLE", "PPG packet err: ${rsp.errCode}")
                            return
                        }
                        // Combine high/low bytes into signed 16-bit accel
                        // values. SDK stores them as separate ints (0-255
                        // each); MEMS accelerometers report ±g as signed
                        // int16, so reinterpret accordingly.
                        val ax = signedInt16(rsp.getXH(), rsp.getXL())
                        val ay = signedInt16(rsp.getYH(), rsp.getYL())
                        val az = signedInt16(rsp.getZH(), rsp.getZL())
                        val sample = mapOf(
                            "timestamp_ms" to System.currentTimeMillis(),
                            "ppg_count" to rsp.ppgCount,
                            "green" to rsp.greenLightPpg,
                            "red" to rsp.redLightPpg,
                            "infrared" to rsp.infraredPpg,
                            "heart" to rsp.heart,
                            "rri" to rsp.rri,
                            "hrv" to rsp.hrv,
                            "accel_x" to ax,
                            "accel_y" to ay,
                            "accel_z" to az
                        )
                        mainHandler.post {
                            ppgEventSink?.success(listOf(sample))
                        }
                    }
                },
                seconds,
                false // false = start measurement
            )
            Log.i("HlthBLE", "PPG capture started for $seconds seconds")
            result.success(mapOf("started" to true, "seconds" to seconds))
        } catch (e: Exception) {
            Log.e("HlthBLE", "startPpgRawCapture failed: ${e.message}", e)
            result.error("PPG_START_FAILED", e.message, null)
        }
    }

    /** Combine high/low bytes into signed 16-bit int. MEMS accelerometers
     *  report ±g as int16, so values above 32767 must wrap to negative. */
    private fun signedInt16(high: Int, low: Int): Int {
        val combined = ((high and 0xFF) shl 8) or (low and 0xFF)
        return if (combined > 32767) combined - 65536 else combined
    }

    private fun stopPpgRawCapture(result: MethodChannel.Result) {
        try {
            BleOperateManager.getInstance().manualModeHeartRateRawData(
                object : ICommandResponse<StopHeartRateRsp> {
                    override fun onDataResponse(rsp: StopHeartRateRsp) {
                        Log.i("HlthBLE", "PPG stop response: type=${rsp.type} err=${rsp.errCode}")
                    }
                },
                0,
                true // true = stop
            )
            result.success(null)
        } catch (e: Exception) {
            Log.e("HlthBLE", "stopPpgRawCapture failed: ${e.message}", e)
            result.error("PPG_STOP_FAILED", e.message, null)
        }
    }

    private fun enableHealthMonitoring(
        hrInterval: Int,
        startInterval: Int,
        spo2Interval: Int,
        hrvInterval: Int,
        result: MethodChannel.Result
    ) {
        try {
            // Heart rate — sdk_ring.pdf §2.3.2 shows the 2-arg form as the
            // canonical "Write continuous heart rate switch" path:
            //   HeartRateSettingReq.getWriteInstance(true, hrInterval)
            // The 5-arg overload with reminders may not be accepted by every
            // firmware. NOTE: on H59 the response's `isEnable` field is
            // unreliable — it returns false even when monitoring is actively
            // collecting data (verified: 472 HR samples accumulated with
            // every ack showing isEnable=false). Treat the response as
            // informational only; the real test is whether sync returns data.
            CommandHandle.getInstance().executeReqCmd(
                HeartRateSettingReq.getWriteInstance(true, hrInterval),
                ICommandResponse<HeartRateSettingRsp> { rsp ->
                    Log.i("HlthBLE", "hr monitoring enable acked: isEnable=${rsp.isEnable} interval=${rsp.heartInterval} mainSwitch=${rsp.mainSwitch}")
                }
            )

            // SpO2 monitoring — `getWriteInstance(true, intervalByte)` enables
            // periodic measurement at `spo2Interval` minutes.
            CommandHandle.getInstance().executeReqCmd(
                BloodOxygenSettingReq.getWriteInstance(true, spo2Interval.toByte()),
                ICommandResponse<BloodOxygenSettingRsp> { rsp ->
                    Log.i("HlthBLE", "spo2 monitoring enable acked: isEnable=${rsp.isEnable}")
                }
            )

            // HRV monitoring — sdk_ring.pdf §2.3.2 documents the direct
            // constructor as the canonical "hrv write interval" form:
            //   HrvSettingReq(true, interval)
            // Same caveat as HR: H59's response is unreliable. Verify via
            // sync after overnight wear, not by the ack.
            CommandHandle.getInstance().executeReqCmd(
                HrvSettingReq(true, hrvInterval),
                ICommandResponse<HRVSettingRsp> { rsp ->
                    Log.i("HlthBLE", "hrv monitoring enable acked: isEnable=${rsp.isEnable}")
                }
            )

            // Read-backs — 2 seconds after the writes, ask the band what it
            // actually stored. On H59 the WRITE response is unreliable
            // (returns isEnable=false even when monitoring is active), but
            // the READ response IS ground truth. Confirmed 2026-05-29:
            // hrv write said isEnable=false; hrv read-back said
            // isEnable=true and HRV monitoring was in fact running.
            mainHandler.postDelayed({
                try {
                    CommandHandle.getInstance().executeReqCmd(
                        HeartRateSettingReq.getReadInstance(),
                        ICommandResponse<HeartRateSettingRsp> { rsp ->
                            Log.i("HlthBLE", "hr  setting read-back: isEnable=${rsp.isEnable} interval=${rsp.heartInterval} mainSwitch=${rsp.mainSwitch}")
                        }
                    )
                    CommandHandle.getInstance().executeReqCmd(
                        BloodOxygenSettingReq.getReadInstance(),
                        ICommandResponse<BloodOxygenSettingRsp> { rsp ->
                            Log.i("HlthBLE", "spo2 setting read-back: isEnable=${rsp.isEnable} interval=${rsp.interval}")
                        }
                    )
                    CommandHandle.getInstance().executeReqCmd(
                        HrvSettingReq.getReadInstance(),
                        ICommandResponse<HRVSettingRsp> { rsp ->
                            Log.i("HlthBLE", "hrv setting read-back: isEnable=${rsp.isEnable}")
                        }
                    )
                } catch (_: Exception) {}
            }, 2000)

            result.success(mapOf(
                "hrInterval" to hrInterval,
                "startInterval" to startInterval,
                "spo2Interval" to spo2Interval,
                "hrvInterval" to hrvInterval
            ))
        } catch (e: Exception) {
            result.error("CONFIG_FAILED", e.message, null)
        }
    }

    private fun readHeartRateSettings(result: MethodChannel.Result) {
        try {
            CommandHandle.getInstance().executeReqCmd(
                HeartRateSettingReq.getReadInstance(),
                ICommandResponse<HeartRateSettingRsp> { rsp ->
                    result.success(mapOf(
                        "isEnable" to rsp.isEnable,
                        "heartInterval" to rsp.heartInterval,
                        "startInterval" to rsp.startInterval,
                        "mainSwitch" to rsp.mainSwitch,
                        "tooLowReminder" to rsp.tooLowReminder,
                        "tooHighReminder" to rsp.tooHighReminder
                    ))
                }
            )
        } catch (e: Exception) {
            result.error("READ_FAILED", e.message, null)
        }
    }

    // ──────────────────────────────────────────────────────────────────────
    // Data sync — the canonical Data Sync command set
    // ──────────────────────────────────────────────────────────────────────

    /**
     * Heart rate sync. Per SDK docs:
     *   - nowTime = unix seconds + timezone-offset-seconds
     *   - Response array has 288 slots/day (5-min resolution)
     *   - For hrInterval=10, only every other slot has a value: [78,0,75,0,77,...]
     *   - Each byte is BPM; 0 = no reading for that slot
     */
    private fun syncHeartRate(result: MethodChannel.Result) {
        val nowTime = unixSecondsWithTzOffset()
        try {
            CommandHandle.getInstance().executeReqCmd(
                ReadHeartRateReq(nowTime),
                ICommandResponse<ReadHeartRateRsp> { rsp ->
                    val array = rsp.getmHeartRateArray()
                    val utcTime = rsp.getmUtcTime()
                    val readings = parseHrArray(array, utcTime.toLong())
                    // `size` and `index` are private with no getters — use reflection.
                    val size = readPrivateInt(rsp, "size")
                    val index = readPrivateInt(rsp, "index")
                    result.success(mapOf(
                        "endFlag" to rsp.isEndFlag,
                        "index" to index,
                        "size" to size,
                        "utcTime" to utcTime,
                        "readings" to readings,
                        "rawArray" to (array?.map { it.toInt() and 0xFF } ?: emptyList<Int>())
                    ))
                    markSync()
                }
            )
        } catch (e: Exception) {
            result.error("SYNC_HR_FAILED", e.message, null)
        }
    }

    /**
     * Parses the heart-rate byte array into a list of {timestamp_ms, bpm}
     * maps. Skips zero values (slots with no reading).
     *
     * Per SDK docs:
     *   "The heart rate data array size is one point every 5(interval) minutes,
     *    the data subscript *5(interval) is equal to the number of minutes of the day"
     *
     * So slot index `i` maps to minute `i * 5` of the day represented by
     * `mUtcTime`. We anchor to midnight of that day's UTC date and add the
     * slot offset.
     */
    private fun parseHrArray(arr: ByteArray?, utcDayAnchor: Long): List<Map<String, Any>> {
        if (arr == null) return emptyList()
        val readings = mutableListOf<Map<String, Any>>()
        // utcDayAnchor is "unix seconds at start of the day" per SDK convention
        val dayStartMs = utcDayAnchor * 1000L
        arr.forEachIndexed { i, b ->
            val bpm = b.toInt() and 0xFF
            if (bpm > 0) {
                readings.add(mapOf(
                    "timestamp_ms" to (dayStartMs + i * 5L * 60_000L),
                    "bpm" to bpm,
                    "slot" to i
                ))
            }
        }
        return readings
    }

    /**
     * SpO2 sync — hourly min/max per day via LargeDataHandler.
     * Each BloodOxygenEntity has minArray[24] and maxArray[24] (hourly).
     */
    private fun syncSpO2(result: MethodChannel.Result) {
        try {
            val all = mutableListOf<Map<String, Any>>()
            LargeDataHandler.getInstance().syncBloodOxygenWithCallback(object : IBloodOxygenCallback {
                override fun readBloodOxygen(data: MutableList<BloodOxygenEntity>?) {
                    if (data == null) {
                        result.success(emptyList<Map<String, Any>>())
                        return
                    }
                    for (entry in data) {
                        all.add(mapOf(
                            "dateStr" to (entry.dateStr ?: ""),
                            "unixTime" to entry.unix_time,
                            "minArray" to (entry.minArray ?: emptyList<Int>()),
                            "maxArray" to (entry.maxArray ?: emptyList<Int>())
                        ))
                    }
                    result.success(all)
                    markSync()
                }
            })
        } catch (e: Exception) {
            result.error("SYNC_SPO2_FAILED", e.message, null)
        }
    }

    /**
     * HRV sync — `HRVReq(offset)` where offset 0=today, 1=yesterday, ... up
     * to 6. Response has `pressureArray` (misnamed in SDK; it's HRV values),
     * one byte per 30-min slot.
     *
     * Scaling: the SDK PDF says "byte / 10 = displayed HRV value", but
     * empirical verification on H59 (2026-06-01, dayOffset=1 returned
     * rawArray [44,0,44,0,38,...]) confirmed the raw bytes are RMSSD in
     * milliseconds, NOT a /10 stress index. 4.6 ms RMSSD is
     * non-physiological; 46 ms is normal adult RMSSD. The SDK's "/10"
     * comment likely refers to a separate stress-score display unit, not
     * the RMSSD ms we persist into `daily_metrics.hrv_rmssd_ms`.
     */
    private fun syncHRV(dayOffset: Int, result: MethodChannel.Result) {
        try {
            CommandHandle.getInstance().executeReqCmd(
                HRVReq(dayOffset.toByte()),
                ICommandResponse<HRVRsp> { rsp ->
                    val arr = rsp.hrvArray
                    // Each byte = RMSSD value in milliseconds, one per 30 min
                    val values = arr?.map { (it.toInt() and 0xFF).toDouble() } ?: emptyList()
                    result.success(mapOf(
                        "values" to values,
                        "intervalMinutes" to rsp.range,
                        "rawArray" to (arr?.map { it.toInt() and 0xFF } ?: emptyList<Int>())
                    ))
                    markSync()
                }
            )
        } catch (e: Exception) {
            result.error("SYNC_HRV_FAILED", e.message, null)
        }
    }

    /**
     * Blood pressure timing-monitor sync. Returns hourly BP measurements
     * (taken automatically once per hour per SDK docs).
     */
    private fun syncBloodPressure(result: MethodChannel.Result) {
        try {
            CommandHandle.getInstance().executeReqCmd(
                SimpleKeyReq(Constants.CMD_BP_TIMING_MONITOR_DATA),
                ICommandResponse<BpDataRsp> { rsp ->
                    val entity = rsp.bpDataEntity
                    if (entity == null) {
                        result.success(emptyMap<String, Any>())
                        return@ICommandResponse
                    }
                    val readings = entity.bpValues?.map { bp ->
                        mapOf(
                            "timeMinute" to bp.timeMinute,
                            "hr" to bp.value
                        )
                    } ?: emptyList<Map<String, Any>>()
                    result.success(mapOf(
                        "year" to entity.year,
                        "month" to entity.mouth, // SDK field is literally "mouth"
                        "day" to entity.day,
                        "timeDelay" to entity.timeDelay,
                        "readings" to readings
                    ))
                    markSync()
                }
            )
        } catch (e: Exception) {
            result.error("SYNC_BP_FAILED", e.message, null)
        }
    }

    /**
     * Sleep sync via the new sleep protocol. Returns sleep stages with
     * type code: 1=deep, 2=light, 3=wake, 4=rem, 5=no_sleep/no_wear.
     */
    private fun syncSleep(dayOffset: Int, result: MethodChannel.Result) {
        try {
            // 2-param variant — the regular `syncSleepList` requires a
            // second launch-sleep callback for lunch-nap support, which
            // we don't need.
            LargeDataHandler.getInstance().syncSleepListIndianDemand(
                dayOffset,
                object : ILargeDataSleepResponse {
                    override fun sleepData(display: SleepDisplay?) {
                        if (display == null) {
                            result.success(emptyMap<String, Any>())
                            return
                        }
                        // SleepDisplay.list is List<SleepDisplay.SleepDataBean>; each
                        // bean exposes getSleepStart()/getSleepEnd() (long) and
                        // getType() (int). The earlier reflection-on-"duration"
                        // approach returned 0 for every stage because the SDK
                        // never had a `duration` field — duration is end-start.
                        val stages = try {
                            (display.list ?: emptyList()).map { bean ->
                                mapOf(
                                    "sleepStart" to bean.sleepStart,
                                    "sleepEnd" to bean.sleepEnd,
                                    "type" to bean.type
                                )
                            }
                        } catch (e: Exception) {
                            Log.w("HlthBLE", "sleep stages parse failed: ${e.message}")
                            emptyList()
                        }
                        result.success(mapOf(
                            "totalSleepDuration" to display.totalSleepDuration,
                            "deepDuration" to display.deepSleepDuration,
                            "shallowDuration" to display.shallowSleepDuration,
                            "awakeDuration" to display.awakeDuration,
                            "rapidDuration" to display.rapidDuration,
                            "sleepTime" to display.sleepTime,
                            "wakeTime" to display.wakeTime,
                            "wakingCount" to display.wakingCount,
                            "stages" to stages
                        ))
                        markSync()
                    }
                }
            )
        } catch (e: Exception) {
            result.error("SYNC_SLEEP_FAILED", e.message, null)
        }
    }

    /**
     * Today's step totals (the screen Chris already saw working —
     * `easySportTotalRspReportTotal`).
     */
    private fun syncSteps(result: MethodChannel.Result) {
        try {
            CommandHandle.getInstance().executeReqCmd(
                SimpleKeyReq(Constants.CMD_GET_STEP_TODAY),
                ICommandResponse<TodaySportDataRsp> { rsp ->
                    val total = rsp.sportTotal
                    if (total == null) {
                        result.success(emptyMap<String, Any>())
                        return@ICommandResponse
                    }
                    result.success(mapOf(
                        "year" to total.year,
                        "month" to total.month,
                        "day" to total.day,
                        "daysAgo" to total.daysAgo,
                        "totalSteps" to total.totalSteps,
                        "runningSteps" to total.runningSteps,
                        "calorie" to total.calorie,
                        "walkDistance" to total.walkDistance,
                        "sportDurationSec" to total.sportDuration,
                        "sleepDurationSec" to total.sleepDuration
                    ))
                    markSync()
                }
            )
        } catch (e: Exception) {
            result.error("SYNC_STEPS_FAILED", e.message, null)
        }
    }

    /**
     * 15-minute-binned step details. 96 points/day. dayOffset 0..6.
     *
     * SDK shape (verified by decompiling the aar):
     *   ReadDetailSportDataRsp.getBleStepDetailses() → ArrayList<BleStepDetails>
     *   BleStepDetails fields: year, month, day, timeIndex (0-95),
     *     walkSteps, runSteps, calorie, distance.
     * Earlier reflection-based parsing returned empty because the getter
     * is `getBleStepDetailses` (double-pluralized typo by SDK author),
     * not `getList`/`getDetails` as we'd been guessing.
     */
    private fun syncStepsDetail(dayOffset: Int, result: MethodChannel.Result) {
        try {
            CommandHandle.getInstance().executeReqCmd(
                ReadDetailSportDataReq(dayOffset, 0, 95),
                ICommandResponse<ReadDetailSportDataRsp> { rsp ->
                    val details: List<BleStepDetails> =
                        rsp.bleStepDetailses ?: emptyList()
                    val bins = details.map { d ->
                        mapOf(
                            "year" to d.year,
                            "month" to d.month,
                            "day" to d.day,
                            "timeIndex" to d.timeIndex,
                            "walkSteps" to d.walkSteps,
                            "runSteps" to d.runSteps,
                            "calorie" to d.calorie,
                            "distance" to d.distance
                        )
                    }
                    result.success(bins)
                    markSync()
                }
            )
        } catch (e: Exception) {
            result.error("SYNC_STEPS_DETAIL_FAILED", e.message, null)
        }
    }

    // ──────────────────────────────────────────────────────────────────────
    // Proactive notifications — band → app
    // ──────────────────────────────────────────────────────────────────────

    private val deviceNotifyListener = object : DeviceNotifyListener() {
        override fun onDataResponse(resultEntity: DeviceNotifyRsp?) {
            if (resultEntity == null) return
            // dataType codes per SDK docs section 2.3.9:
            //   1 = heart rate update
            //   2 = blood pressure update
            //   3 = blood oxygen update
            //   4 = step counting update
            //   5 = temperature update
            //   7 = new exercise record
            //   0x0c = charging state
            mainHandler.post {
                methodChannel.invokeMethod(
                    "onDeviceNotify",
                    mapOf(
                        "dataType" to resultEntity.dataType,
                        "loadData" to (resultEntity.loadData?.map { it.toInt() and 0xFF }
                            ?: emptyList<Int>())
                    )
                )
            }
            // HLT-9: realtime HR push. Per hlth-ble-platform-channel.md §realtime
            // streams, `realtime_hr` comes from `DeviceNotifyListener` on
            // Android. The notification itself is just a trigger
            // ("new HR data exists") — `loadData` does NOT carry BPM (verified
            // against QRing demo's MyDeviceNotifyListener — they comment-out
            // a follow-up sync call in the dataType=1 branch). So we do the
            // sync ourselves, find the latest non-zero slot, and emit it on
            // `onRealtimeHeartRate` which Dart smooths over a 5-sec window.
            if (resultEntity.dataType == 1) {
                triggerRealtimeHrSync()
            }
        }
    }

    /** HLT-9: poke the band for the latest HR reading after a dataType=1
     *  notification fires, then emit the freshest BPM on the realtime
     *  channel. Debounced to once per 5 sec so we don't saturate the BLE
     *  channel if notifications batch (which they sometimes do on H59). */
    private fun triggerRealtimeHrSync() {
        val now = System.currentTimeMillis()
        if (now - lastRealtimeHrSyncMs < 5_000L) return
        lastRealtimeHrSyncMs = now
        try {
            val nowTime = unixSecondsWithTzOffset()
            CommandHandle.getInstance().executeReqCmd(
                ReadHeartRateReq(nowTime),
                ICommandResponse<ReadHeartRateRsp> { rsp ->
                    val arr = rsp.getmHeartRateArray() ?: return@ICommandResponse
                    // Scan from the end of the day's slot array — the most
                    // recent reading is the highest-index non-zero slot.
                    var latestBpm = 0
                    for (i in arr.size - 1 downTo 0) {
                        val bpm = arr[i].toInt() and 0xFF
                        if (bpm > 0) {
                            latestBpm = bpm
                            break
                        }
                    }
                    if (latestBpm > 0) {
                        mainHandler.post {
                            methodChannel.invokeMethod(
                                "onRealtimeHeartRate",
                                mapOf("bpm" to latestBpm)
                            )
                        }
                    }
                }
            )
        } catch (e: Exception) {
            Log.w("HlthBLE", "realtime HR trigger sync failed: ${e.message}")
        }
    }

    // ──────────────────────────────────────────────────────────────────────
    // Helpers
    // ──────────────────────────────────────────────────────────────────────

    /**
     * Per SDK docs:
     *   val time = (getTimeZone() * 3600).toInt()
     *   val nowTime = date.unixTimestamp + time
     *
     * This shifts unix seconds by the local TZ offset so the band can locate
     * "today" without doing timezone math on its side.
     */
    /**
     * Returns unix seconds + local TZ offset seconds. `ReadHeartRateReq`
     * expects a Long.
     */
    private fun unixSecondsWithTzOffset(): Long {
        val now = System.currentTimeMillis() / 1000L
        val tzOffsetSec = TimeZone.getDefault()
            .getOffset(System.currentTimeMillis()) / 1000L
        return now + tzOffsetSec
    }

    /**
     * Notify the foreground service that a sync just completed so the
     * persistent notification can update its "Last synced Xm ago" text.
     * No-op when we're not connected (service won't be running).
     */
    private fun markSync() {
        if (connectedDeviceName.isEmpty()) return
        BleForegroundService.updateLastSync(
            context,
            connectedDeviceName,
            System.currentTimeMillis()
        )
    }

    /**
     * Reads a private int field from a Java object via reflection. Used for
     * SDK response classes that don't expose getters for their fields (e.g.,
     * ReadHeartRateRsp.size / ReadHeartRateRsp.index).
     */
    private fun readPrivateInt(target: Any, fieldName: String): Int {
        return try {
            target.javaClass.getDeclaredField(fieldName).apply {
                isAccessible = true
            }.getInt(target)
        } catch (_: Exception) {
            0
        }
    }

}
