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
import com.oudmon.ble.base.communication.LargeDataHandler
import com.oudmon.ble.base.communication.bigData.BloodOxygenEntity
import com.oudmon.ble.base.communication.bigData.IBloodOxygenCallback
import com.oudmon.ble.base.communication.entity.BlePressure
import com.oudmon.ble.base.communication.entity.BleStepDetails
import com.oudmon.ble.base.communication.entity.StartEndTimeEntity
import com.oudmon.ble.base.communication.req.BloodOxygenSettingReq
import com.oudmon.ble.base.communication.req.BpSettingReq
import com.oudmon.ble.base.communication.req.HeartRateSettingReq
import com.oudmon.ble.base.communication.req.HrvSettingReq
import com.oudmon.ble.base.communication.req.ReadDetailSportDataReq
import com.oudmon.ble.base.communication.req.ReadHeartRateReq
import com.oudmon.ble.base.communication.req.SetTimeReq
import com.oudmon.ble.base.communication.req.SimpleKeyReq
import com.oudmon.ble.base.communication.responseImpl.DeviceNotifyListener
import com.oudmon.ble.base.communication.rsp.BaseRspCmd
import com.oudmon.ble.base.communication.rsp.BloodOxygenSettingRsp
import com.oudmon.ble.base.communication.rsp.BpDataRsp
import com.oudmon.ble.base.communication.rsp.BpSettingRsp
import com.oudmon.ble.base.communication.rsp.DeviceNotifyRsp
import com.oudmon.ble.base.communication.rsp.HRVRsp
import com.oudmon.ble.base.communication.rsp.HRVSettingRsp
import com.oudmon.ble.base.communication.rsp.HeartRateSettingRsp
import com.oudmon.ble.base.communication.rsp.ReadDetailSportDataRsp
import com.oudmon.ble.base.communication.rsp.ReadHeartRateRsp
import com.oudmon.ble.base.communication.rsp.SetTimeRsp
import com.oudmon.ble.base.communication.rsp.StartHeartRateRsp
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

        // Scan name-prefix allowlist (see [isHlthBandName]). Mirrors the
        // QRing SDK's internal BleScannerHelper.sFILTER_PREFIX list +
        // "H59" for the current HLTH band. Matched case-insensitively, so
        // upper/lower variants collapse (O_/o_, Q_/q_, QC/qc).
        private val BAND_NAME_PREFIXES = listOf(
            "H59",
            "O_", "Q_", "R3L", "QC", "Wa",
            "T80", "T90", "T91", "T93", "T95", "TW68",
            "S9",
            "C60", "C66", "C67", "C68", "C80", "C86", "C88", "C96",
            "wxb_w4"
        )
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
    private var connectedAddress: String = ""
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
            // Auto-close any active manualMode streams when the band drops
            // so callbacks don't fire after we're gone.
            if (!connected) {
                heartStreamActive = false
                spo2StreamActive = false
                hrvStreamActive = false
                okmActive = false
            }
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
                bpIntervalMinutes = call.argument<Int>("bpIntervalMinutes") ?: 60,
                result = result
            )
            "getScheduledHr" -> readHeartRateSettings(result)
            "setBpScheduled" -> setBpScheduled(
                enabled = call.argument<Boolean>("enabled") ?: true,
                intervalMinutes = call.argument<Int>("intervalMinutes") ?: 60,
                startHour = call.argument<Int>("startHour") ?: 0,
                startMinute = call.argument<Int>("startMinute") ?: 0,
                endHour = call.argument<Int>("endHour") ?: 23,
                endMinute = call.argument<Int>("endMinute") ?: 59,
                result = result
            )
            "getBpScheduled" -> getBpScheduled(result)

            // §3.7 History fetch
            "getHrHistory" -> syncHeartRate(call.argument<Int>("dayOffset") ?: 0, result)
            "getSpO2History" -> syncSpO2(result)
            "getSpO2Day" -> syncSpO2Day(call.argument<Int>("dayOffset") ?: 0, result)
            "getHrvHistory" -> syncHRV(call.argument<Int>("dayOffset") ?: 0, result)
            "getBpHistory" -> syncBloodPressure(result)
            "getBpDay" -> syncBloodPressureDay(call.argument<Int>("dayOffset") ?: 0, result)
            "startBpMeasurement" -> startBpMeasurement(result)
            "stopBpMeasurement" -> stopBpMeasurement(result)
            "startHeartStream" -> startHeartStream(result)
            "stopHeartStream" -> stopHeartStream(result)
            "startSpo2Stream" -> startSpo2Stream(result)
            "stopSpo2Stream" -> stopSpo2Stream(result)
            "startHrvStream" -> startHrvStream(result)
            "stopHrvStream" -> stopHrvStream(result)
            "startOneKeyMeasurement" -> startOneKeyMeasurement(result)
            "stopOneKeyMeasurement" -> stopOneKeyMeasurement(result)
            "getSleepHistory" -> syncSleep(call.argument<Int>("dayOffset") ?: 0, result)
            "getDailyTotals" -> syncSteps(result)
            "getStepBucketHistory" -> syncStepsDetail(call.argument<Int>("dayOffset") ?: 0, result)
            "getStepDay" -> syncStepsDay(call.argument<Int>("dayOffset") ?: 0, result)

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

    /**
     * Mirror of the QRing demo's scan filter behavior. The SDK's
     * BleScannerHelper applies a hardcoded prefix allowlist
     * (O_, Q_, R3L, QC, T8x, C6x, S9, TW68, wxb_w4, Wa) that excludes
     * everything else. The HLTH band advertises as "H59_xxxx", so we
     * extend that list with "H59" (case-insensitive) — that's why the
     * demo screen shows only the band, even though nearby phones / TVs /
     * earbuds advertise too.
     *
     * If you ever onboard a different HLTH device model, add its prefix
     * here.
     */
    private fun isHlthBandName(name: String?): Boolean {
        if (name.isNullOrEmpty()) return false
        return BAND_NAME_PREFIXES.any { name.startsWith(it, ignoreCase = true) }
    }

    private val directScanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult?) {
            val device = result?.device ?: return
            val name = try { device.name } catch (_: SecurityException) { null }
            val address = device.address ?: return
            Log.d("HlthBLE", "direct scan hit: addr=$address name=$name rssi=${result.rssi}")
            if (!isHlthBandName(name)) return
            discoveredDevices[address] = ScanEntry(
                name = name!!,
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
            if (!isHlthBandName(name)) return
            discoveredDevices[device.address] = ScanEntry(
                name = name!!,
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
            connectedAddress = deviceId
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
        bpIntervalMinutes: Int,
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

            // Scheduled BP monitoring — `BpSettingReq.getWriteInstance`
            // takes an active-window + minute cadence. Default: all day,
            // every 60 minutes. Matches the QRing demo's BP setting call
            // shape (BloodPressureActivity.kt:83). Without this, the band
            // never auto-measures BP and the home-screen BP card stays
            // empty until a manual measurement is taken.
            CommandHandle.getInstance().executeReqCmd(
                BpSettingReq.getWriteInstance(
                    true,
                    StartEndTimeEntity(0, 0, 23, 59),
                    bpIntervalMinutes
                ),
                ICommandResponse<BpSettingRsp> { rsp ->
                    Log.i(
                        "HlthBLE",
                        "bp monitoring enable acked: isEnable=${rsp.isEnable} multiple=${rsp.multiple}"
                    )
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
                    CommandHandle.getInstance().executeReqCmd(
                        BpSettingReq.getReadInstance(),
                        ICommandResponse<BpSettingRsp> { rsp ->
                            Log.i("HlthBLE", "bp  setting read-back: isEnable=${rsp.isEnable} multiple=${rsp.multiple}")
                        }
                    )
                } catch (_: Exception) {}
            }, 2000)

            result.success(mapOf(
                "hrInterval" to hrInterval,
                "startInterval" to startInterval,
                "spo2Interval" to spo2Interval,
                "hrvInterval" to hrvInterval,
                "bpIntervalMinutes" to bpIntervalMinutes
            ))
        } catch (e: Exception) {
            result.error("CONFIG_FAILED", e.message, null)
        }
    }

    /**
     * Write the band's scheduled BP monitoring config. The band auto-runs
     * a BP measurement every `intervalMinutes` between (startHour:Minute)
     * and (endHour:Minute). Common case: enabled=true, all-day window,
     * intervalMinutes=60.
     *
     * H59 quirk shared with HR/SpO2/HRV: the write ack's `isEnable` field
     * is unreliable — always confirm via `getBpScheduled` after a short
     * delay if you want ground truth.
     */
    private fun setBpScheduled(
        enabled: Boolean,
        intervalMinutes: Int,
        startHour: Int,
        startMinute: Int,
        endHour: Int,
        endMinute: Int,
        result: MethodChannel.Result
    ) {
        try {
            Log.i(
                "HlthBLE",
                "setBpScheduled: enabled=$enabled interval=${intervalMinutes}min window=$startHour:$startMinute→$endHour:$endMinute"
            )
            CommandHandle.getInstance().executeReqCmd(
                BpSettingReq.getWriteInstance(
                    enabled,
                    StartEndTimeEntity(startHour, startMinute, endHour, endMinute),
                    intervalMinutes
                ),
                ICommandResponse<BpSettingRsp> { rsp ->
                    Log.i(
                        "HlthBLE",
                        "setBpScheduled ack: isEnable=${rsp.isEnable} multiple=${rsp.multiple}"
                    )
                    result.success(mapOf(
                        "isEnable" to rsp.isEnable,
                        "intervalMinutes" to rsp.multiple
                    ))
                }
            )
        } catch (e: Exception) {
            Log.e("HlthBLE", "setBpScheduled failed", e)
            result.error("BP_SCHED_FAILED", e.message, null)
        }
    }

    private fun getBpScheduled(result: MethodChannel.Result) {
        try {
            CommandHandle.getInstance().executeReqCmd(
                BpSettingReq.getReadInstance(),
                ICommandResponse<BpSettingRsp> { rsp ->
                    val w = rsp.startEndTimeEntity
                    Log.i(
                        "HlthBLE",
                        "getBpScheduled: isEnable=${rsp.isEnable} multiple=${rsp.multiple} window=${w?.startHour}:${w?.startMinute}→${w?.endHour}:${w?.endMinute}"
                    )
                    result.success(mapOf(
                        "isEnable" to rsp.isEnable,
                        "intervalMinutes" to rsp.multiple,
                        "startHour" to (w?.startHour ?: 0),
                        "startMinute" to (w?.startMinute ?: 0),
                        "endHour" to (w?.endHour ?: 23),
                        "endMinute" to (w?.endMinute ?: 59)
                    ))
                }
            )
        } catch (e: Exception) {
            Log.e("HlthBLE", "getBpScheduled failed", e)
            result.error("BP_SCHED_READ_FAILED", e.message, null)
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
    private fun syncHeartRate(dayOffset: Int, result: MethodChannel.Result) {
        // Uses the SDK's public API path (same as QRing demo's "Today Data" /
        // "Specific Day Data" buttons — see HeartRateActivity.kt:54-58). The
        // old direct `CommandHandle.executeReqCmd(ReadHeartRateReq(nowTime))`
        // path worked for today's HR but had no day-offset support and
        // bypassed the SDK's task scheduler. Switching to BleOperateManager
        // gives us the same response shape (ReadHeartRateRsp) plus proper
        // queueing, error routing, and dayOffset 0..29 backfill.
        val replied = java.util.concurrent.atomic.AtomicBoolean(false)
        val callback = object : BleOperateManager.HealthDataCallback<ReadHeartRateRsp> {
            override fun onSuccess(rsp: ReadHeartRateRsp?) {
                if (!replied.compareAndSet(false, true)) return
                if (rsp == null) {
                    Log.i("HlthBLE", "syncHR: onSuccess(null) — no HR data for day=$dayOffset")
                    result.success(emptyMap<String, Any>())
                    return
                }
                val array = rsp.getmHeartRateArray()
                val utcTime = rsp.getmUtcTime()
                val readings = parseHrArray(array, utcTime.toLong())
                val size = readPrivateInt(rsp, "size")
                val index = readPrivateInt(rsp, "index")
                Log.i("HlthBLE", "syncHR: onSuccess day=$dayOffset utcTime=$utcTime size=$size readings=${readings.size}")
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

            override fun onError(code: Int, message: String?) {
                if (!replied.compareAndSet(false, true)) return
                Log.w("HlthBLE", "syncHR: onError code=$code msg=$message")
                result.error("SYNC_HR_FAILED", message ?: "code=$code", code)
            }
        }
        try {
            Log.i("HlthBLE", "syncHR: dayOffset=$dayOffset (BleOperateManager.getHeartRate)")
            if (dayOffset == 0) {
                BleOperateManager.getInstance().getTodayHeartRate(callback)
            } else {
                BleOperateManager.getInstance().getHeartRate(dayOffset, callback)
            }
        } catch (e: Exception) {
            if (replied.compareAndSet(false, true)) {
                Log.e("HlthBLE", "syncHR dayOffset=$dayOffset failed", e)
                result.error("SYNC_HR_FAILED", e.message, null)
            }
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
     * SpO2 single-day sync via the SDK's public per-day API (same call the
     * QRing demo's "Specific Day Data" / "Today Data" buttons use — see
     * BloodOxygenActivity.kt:78-84). dayOffset=0 maps to `getTodayBloodOxygen`,
     * 1..29 to `getBloodOxygen(dayIndex)`. Response shape is the same
     * BloodOxygenEntity that bulk sync already returns, so the Dart adapter
     * doesn't need new code — we wrap it in a single-element list to match
     * the bulk method's contract.
     */
    private fun syncSpO2Day(dayOffset: Int, result: MethodChannel.Result) {
        val replied = java.util.concurrent.atomic.AtomicBoolean(false)
        val callback = object : BleOperateManager.HealthDataCallback<BloodOxygenEntity> {
            override fun onSuccess(entry: BloodOxygenEntity?) {
                if (!replied.compareAndSet(false, true)) return
                if (entry == null) {
                    Log.i("HlthBLE", "syncSpO2Day: onSuccess(null) — no SpO2 data for day=$dayOffset")
                    result.success(emptyList<Map<String, Any>>())
                    return
                }
                Log.i("HlthBLE", "syncSpO2Day: onSuccess day=$dayOffset dateStr=${entry.dateStr} unix=${entry.unix_time}")
                result.success(listOf(mapOf(
                    "dateStr" to (entry.dateStr ?: ""),
                    "unixTime" to entry.unix_time,
                    "minArray" to (entry.minArray ?: emptyList<Int>()),
                    "maxArray" to (entry.maxArray ?: emptyList<Int>())
                )))
                markSync()
            }

            override fun onError(code: Int, message: String?) {
                if (!replied.compareAndSet(false, true)) return
                Log.w("HlthBLE", "syncSpO2Day: onError code=$code msg=$message")
                result.error("SYNC_SPO2_FAILED", message ?: "code=$code", code)
            }
        }
        try {
            Log.i("HlthBLE", "syncSpO2Day: dayOffset=$dayOffset (BleOperateManager.getBloodOxygen)")
            if (dayOffset == 0) {
                BleOperateManager.getInstance().getTodayBloodOxygen(callback)
            } else {
                BleOperateManager.getInstance().getBloodOxygen(dayOffset, callback)
            }
        } catch (e: Exception) {
            if (replied.compareAndSet(false, true)) {
                Log.e("HlthBLE", "syncSpO2Day dayOffset=$dayOffset failed", e)
                result.error("SYNC_SPO2_FAILED", e.message, null)
            }
        }
    }

    /**
     * SpO2 sync — hourly min/max per day via LargeDataHandler. Returns ALL
     * stored days in one call. Each BloodOxygenEntity has minArray[24] and
     * maxArray[24] (hourly). Equivalent to the QRing demo's
     * "Sync Blood Oxygen Data" button.
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
        // Uses the SDK's public per-day API — same call the QRing demo's
        // "Today Data" / "Specific Day Data" buttons use (see
        // HrvActivity.kt:bindHealthQueryActions). dayOffset=0 →
        // getTodayHrv, 1..29 → getHrv(dayIndex). Same HRVRsp response so
        // the Dart adapter is unchanged.
        val replied = java.util.concurrent.atomic.AtomicBoolean(false)
        val callback = object : BleOperateManager.HealthDataCallback<HRVRsp> {
            override fun onSuccess(rsp: HRVRsp?) {
                if (!replied.compareAndSet(false, true)) return
                if (rsp == null) {
                    Log.i("HlthBLE", "syncHRV: onSuccess(null) — no HRV data for day=$dayOffset")
                    result.success(emptyMap<String, Any>())
                    return
                }
                val arr = rsp.hrvArray
                val values = arr?.map { (it.toInt() and 0xFF).toDouble() } ?: emptyList()
                Log.i("HlthBLE", "syncHRV: onSuccess day=$dayOffset range=${rsp.range} arrSize=${arr?.size ?: 0}")
                result.success(mapOf(
                    "values" to values,
                    "intervalMinutes" to rsp.range,
                    "rawArray" to (arr?.map { it.toInt() and 0xFF } ?: emptyList<Int>())
                ))
                markSync()
            }

            override fun onError(code: Int, message: String?) {
                if (!replied.compareAndSet(false, true)) return
                Log.w("HlthBLE", "syncHRV: onError code=$code msg=$message")
                result.error("SYNC_HRV_FAILED", message ?: "code=$code", code)
            }
        }
        try {
            Log.i("HlthBLE", "syncHRV: dayOffset=$dayOffset (BleOperateManager.getHrv)")
            if (dayOffset == 0) {
                BleOperateManager.getInstance().getTodayHrv(callback)
            } else {
                BleOperateManager.getInstance().getHrv(dayOffset, callback)
            }
        } catch (e: Exception) {
            if (replied.compareAndSet(false, true)) {
                Log.e("HlthBLE", "syncHRV dayOffset=$dayOffset failed", e)
                result.error("SYNC_HRV_FAILED", e.message, null)
            }
        }
    }

    /**
     * BP single-day sync via the SDK's public per-day API. Same call the
     * QRing demo's "Specific Day Data" button uses (BloodPressureActivity.kt:44).
     * Returns `List<BlePressure>` where each entry has time/sbp/dbp — these
     * are **real systolic/diastolic pairs**, unlike the legacy
     * `CMD_BP_TIMING_MONITOR_DATA` path which on H59 returns HR values
     * disguised as BP. Prefer this for any actual BP querying.
     */
    private fun syncBloodPressureDay(dayOffset: Int, result: MethodChannel.Result) {
        val replied = java.util.concurrent.atomic.AtomicBoolean(false)
        val callback = object : BleOperateManager.HealthDataCallback<MutableList<BlePressure>> {
            override fun onSuccess(list: MutableList<BlePressure>?) {
                if (!replied.compareAndSet(false, true)) return
                if (list == null) {
                    Log.i("HlthBLE", "syncBpDay: onSuccess(null) — no BP data for day=$dayOffset")
                    result.success(emptyMap<String, Any>())
                    return
                }
                Log.i("HlthBLE", "syncBpDay: onSuccess day=$dayOffset count=${list.size}")
                result.success(mapOf(
                    "readings" to list.map { bp ->
                        mapOf("time" to bp.time, "sbp" to bp.sbp, "dbp" to bp.dbp)
                    }
                ))
                markSync()
            }

            override fun onError(code: Int, message: String?) {
                if (!replied.compareAndSet(false, true)) return
                Log.w("HlthBLE", "syncBpDay: onError code=$code msg=$message")
                result.error("SYNC_BP_FAILED", message ?: "code=$code", code)
            }
        }
        try {
            Log.i("HlthBLE", "syncBpDay: dayOffset=$dayOffset (BleOperateManager.getBloodPressure)")
            if (dayOffset == 0) {
                BleOperateManager.getInstance().getTodayBloodPressure(callback)
            } else {
                BleOperateManager.getInstance().getBloodPressure(dayOffset, callback)
            }
        } catch (e: Exception) {
            if (replied.compareAndSet(false, true)) {
                Log.e("HlthBLE", "syncBpDay dayOffset=$dayOffset failed", e)
                result.error("SYNC_BP_FAILED", e.message, null)
            }
        }
    }

    /**
     * Trigger an on-demand BP measurement. Same as the QRing demo's
     * "Start Blood Pressure Measurement" button (BloodPressureActivity.kt:101).
     * The band runs an active measurement (~30s) and fires the callback
     * with sbp/dbp/heartRate. Use [stopBpMeasurement] to abort.
     */
    private fun startBpMeasurement(result: MethodChannel.Result) {
        val replied = java.util.concurrent.atomic.AtomicBoolean(false)
        try {
            Log.i("HlthBLE", "startBpMeasurement: launching active measurement")
            BleOperateManager.getInstance().manualModeBP(
                ICommandResponse<StartHeartRateRsp> { rsp ->
                    if (!replied.compareAndSet(false, true)) return@ICommandResponse
                    if (rsp.status != BaseRspCmd.RESULT_OK) {
                        Log.w("HlthBLE", "startBpMeasurement: status=${rsp.status} errCode=${rsp.errCode}")
                        result.error("BP_MEASURE_FAILED", "status=${rsp.status}", null)
                        return@ICommandResponse
                    }
                    Log.i("HlthBLE", "startBpMeasurement: sbp=${rsp.sbp} dbp=${rsp.dbp} hr=${rsp.heartRate}")
                    result.success(mapOf(
                        "sbp" to rsp.sbp,
                        "dbp" to rsp.dbp,
                        "hr" to rsp.heartRate,
                        "errCode" to rsp.errCode.toInt()
                    ))
                    markSync()
                },
                false  // false = start, true = stop
            )
        } catch (e: Exception) {
            if (replied.compareAndSet(false, true)) {
                Log.e("HlthBLE", "startBpMeasurement failed", e)
                result.error("BP_MEASURE_FAILED", e.message, null)
            }
        }
    }

    /** Abort an in-flight BP measurement (the "Stop Blood Pressure Measurement" demo button). */
    private fun stopBpMeasurement(result: MethodChannel.Result) {
        val replied = java.util.concurrent.atomic.AtomicBoolean(false)
        try {
            Log.i("HlthBLE", "stopBpMeasurement: aborting active measurement")
            BleOperateManager.getInstance().manualModeBP(
                ICommandResponse<StartHeartRateRsp> { rsp ->
                    if (!replied.compareAndSet(false, true)) return@ICommandResponse
                    result.success(mapOf("stopped" to (rsp.status == BaseRspCmd.RESULT_OK)))
                },
                true
            )
        } catch (e: Exception) {
            if (replied.compareAndSet(false, true)) {
                Log.e("HlthBLE", "stopBpMeasurement failed", e)
                result.error("BP_MEASURE_FAILED", e.message, null)
            }
        }
    }

    // ──────────────────────────────────────────────────────────────────────
    // Realtime measurement streams (manualMode* SDK APIs).
    //
    // SDK semantics (verified against the QRing demo + on-device): each
    // `manualMode*(..., false)` kicks off a ~30-60s active band-side
    // measurement. The callback fires once when the band has a converged
    // value (or earlier with `value=0` if motion/contact aborts the read,
    // which we filter out below). It is NOT a per-second tick stream —
    // expect 1 update per Start, not 30. For per-second continuous data
    // use the PPG raw stream (startMeasureHrRaw) instead.
    //
    // `manualMode*(..., true)` terminates the in-flight measurement.
    //
    // Not streamable per SDK PDF / API surface — explicitly noted so we
    // don't keep re-asking:
    //   • Sleep — only available via the daily-sync window (no live push)
    //   • Step buckets / daily step totals — sync-only; the only "live"
    //     step signal is DeviceNotifyListener dataType=4, which fires
    //     once per band-side step count update (not a continuous stream).
    //   • Temperature, ECG — H59 firmware doesn't expose these as streams
    //     (only as on-demand single reads via syncTemperature equivalents).
    // ──────────────────────────────────────────────────────────────────────

    private var heartStreamActive = false
    private var spo2StreamActive = false
    private var hrvStreamActive = false

    private fun startHeartStream(result: MethodChannel.Result) {
        if (heartStreamActive) {
            result.success(mapOf("started" to false, "reason" to "already streaming"))
            return
        }
        heartStreamActive = true
        try {
            Log.i("HlthBLE", "startHeartStream: subscribing to manualModeHeart")
            BleOperateManager.getInstance().manualModeHeart(
                ICommandResponse<StartHeartRateRsp> { rsp ->
                    if (!heartStreamActive) return@ICommandResponse
                    if (rsp.status != BaseRspCmd.RESULT_OK) {
                        Log.w("HlthBLE", "hr stream tick: status=${rsp.status}")
                        return@ICommandResponse
                    }
                    val hr = when {
                        rsp.heartRate > 0 -> rsp.heartRate
                        rsp.heart > 0 -> rsp.heart
                        rsp.value > 0 -> rsp.value
                        else -> 0
                    }
                    if (hr <= 0) {
                        Log.d("HlthBLE", "hr stream pre-converge tick")
                        return@ICommandResponse
                    }
                    mainHandler.post {
                        methodChannel.invokeMethod(
                            "onHeartStream",
                            mapOf("hr" to hr)
                        )
                    }
                },
                false
            )
            result.success(mapOf("started" to true))
        } catch (e: Exception) {
            heartStreamActive = false
            Log.e("HlthBLE", "startHeartStream failed", e)
            result.error("HR_STREAM_FAILED", e.message, null)
        }
    }

    private fun stopHeartStream(result: MethodChannel.Result) {
        if (!heartStreamActive) {
            result.success(mapOf("stopped" to false, "reason" to "not streaming"))
            return
        }
        heartStreamActive = false
        try {
            Log.i("HlthBLE", "stopHeartStream: stopping manualModeHeart")
            BleOperateManager.getInstance().manualModeHeart(
                ICommandResponse<StartHeartRateRsp> { _ -> },
                true
            )
            result.success(mapOf("stopped" to true))
        } catch (e: Exception) {
            Log.e("HlthBLE", "stopHeartStream failed", e)
            result.error("HR_STREAM_FAILED", e.message, null)
        }
    }

    private fun startSpo2Stream(result: MethodChannel.Result) {
        if (spo2StreamActive) {
            result.success(mapOf("started" to false, "reason" to "already streaming"))
            return
        }
        spo2StreamActive = true
        try {
            Log.i("HlthBLE", "startSpo2Stream: subscribing to manualModeSpO2")
            BleOperateManager.getInstance().manualModeSpO2(
                ICommandResponse<StartHeartRateRsp> { rsp ->
                    if (!spo2StreamActive) return@ICommandResponse
                    if (rsp.status != BaseRspCmd.RESULT_OK) {
                        Log.w("HlthBLE", "spo2 stream tick: status=${rsp.status}")
                        return@ICommandResponse
                    }
                    // Demo fallback (BloodOxygenActivity.kt:108): SDK puts
                    // the converged SpO2 in `bloodOxygen` for some fw
                    // builds and in `value` for others.
                    val spo2 = if (rsp.bloodOxygen > 0) rsp.bloodOxygen else rsp.value
                    val hr = rsp.heartRate
                    if (spo2 <= 0) {
                        // Pre-convergence noise — band still warming up.
                        Log.d("HlthBLE", "spo2 stream pre-converge tick")
                        return@ICommandResponse
                    }
                    mainHandler.post {
                        methodChannel.invokeMethod(
                            "onSpo2Stream",
                            mapOf("spo2" to spo2, "hr" to hr)
                        )
                    }
                },
                false
            )
            result.success(mapOf("started" to true))
        } catch (e: Exception) {
            spo2StreamActive = false
            Log.e("HlthBLE", "startSpo2Stream failed", e)
            result.error("SPO2_STREAM_FAILED", e.message, null)
        }
    }

    private fun stopSpo2Stream(result: MethodChannel.Result) {
        if (!spo2StreamActive) {
            result.success(mapOf("stopped" to false, "reason" to "not streaming"))
            return
        }
        spo2StreamActive = false
        try {
            Log.i("HlthBLE", "stopSpo2Stream: stopping manualModeSpO2")
            BleOperateManager.getInstance().manualModeSpO2(
                ICommandResponse<StartHeartRateRsp> { _ -> },
                true
            )
            result.success(mapOf("stopped" to true))
        } catch (e: Exception) {
            Log.e("HlthBLE", "stopSpo2Stream failed", e)
            result.error("SPO2_STREAM_FAILED", e.message, null)
        }
    }

    private fun startHrvStream(result: MethodChannel.Result) {
        if (hrvStreamActive) {
            result.success(mapOf("started" to false, "reason" to "already streaming"))
            return
        }
        hrvStreamActive = true
        try {
            Log.i("HlthBLE", "startHrvStream: subscribing to manualModeHrv")
            BleOperateManager.getInstance().manualModeHrv(
                ICommandResponse<StartHeartRateRsp> { rsp ->
                    if (!hrvStreamActive) return@ICommandResponse
                    if (rsp.status != BaseRspCmd.RESULT_OK) {
                        Log.w("HlthBLE", "hrv stream tick: status=${rsp.status}")
                        return@ICommandResponse
                    }
                    // Same value-fallback as SpO2 (HrvActivity.kt:109).
                    val hrv = if (rsp.hrv > 0) rsp.hrv else rsp.value
                    val hr = rsp.heartRate
                    val stress = rsp.stress
                    if (hrv <= 0) {
                        Log.d("HlthBLE", "hrv stream pre-converge tick")
                        return@ICommandResponse
                    }
                    mainHandler.post {
                        methodChannel.invokeMethod(
                            "onHrvStream",
                            mapOf("hrv" to hrv, "hr" to hr, "stress" to stress)
                        )
                    }
                },
                false
            )
            result.success(mapOf("started" to true))
        } catch (e: Exception) {
            hrvStreamActive = false
            Log.e("HlthBLE", "startHrvStream failed", e)
            result.error("HRV_STREAM_FAILED", e.message, null)
        }
    }

    private fun stopHrvStream(result: MethodChannel.Result) {
        if (!hrvStreamActive) {
            result.success(mapOf("stopped" to false, "reason" to "not streaming"))
            return
        }
        hrvStreamActive = false
        try {
            Log.i("HlthBLE", "stopHrvStream: stopping manualModeHrv")
            BleOperateManager.getInstance().manualModeHrv(
                ICommandResponse<StartHeartRateRsp> { _ -> },
                true
            )
            result.success(mapOf("stopped" to true))
        } catch (e: Exception) {
            Log.e("HlthBLE", "stopHrvStream failed", e)
            result.error("HRV_STREAM_FAILED", e.message, null)
        }
    }

    // ─── One Key Measurement BP phase (manualModeBP per PDF 2.3.7) ──────
    //
    // The SDK's official `startOneKey(0, 0, cb)` mode-5 API is broken on
    // H59 firmware: the band returns raw-PPG packets (type=13) on notify
    // 0x69 instead of the combined health-check packet the SDK's
    // OneKeyResp wrapper expects, causing an unrecoverable
    // ClassCastException inside the SDK's QCDataParser dispatch path
    // (confirmed 2026-06-11). No app-side workaround.
    //
    // So this "okm" call is just the BP leg of a chained measurement:
    // `manualModeBP(cb, false)` — runs a ~30s active BP measurement and
    // returns sbp/dbp via StartHeartRateRsp. The Dart screen orchestrates
    // the HR → SpO2 → BP chain by calling startHeartStream /
    // startSpo2Stream / startOneKeyMeasurement in sequence.

    private var okmActive = false

    private fun startOneKeyMeasurement(result: MethodChannel.Result) {
        if (okmActive) {
            result.success(mapOf("started" to false, "reason" to "already running"))
            return
        }
        okmActive = true
        try {
            Log.i("HlthBLE", "startOneKeyMeasurement: manualModeBP (BP leg)")
            BleOperateManager.getInstance().manualModeBP(
                ICommandResponse<StartHeartRateRsp> { rsp ->
                    if (!okmActive) return@ICommandResponse
                    if (rsp.status != BaseRspCmd.RESULT_OK) {
                        Log.w("HlthBLE", "okm/bp tick: status=${rsp.status}")
                        return@ICommandResponse
                    }
                    val sbp = rsp.sbp
                    val dbp = rsp.dbp
                    val hr = rsp.heartRate
                    if (sbp <= 0 || dbp <= 0) {
                        Log.d("HlthBLE", "okm/bp pre-converge tick")
                        return@ICommandResponse
                    }
                    Log.i(
                        "HlthBLE",
                        "okm/bp tick: sbp=$sbp dbp=$dbp hr=$hr err=${rsp.errCode}"
                    )
                    mainHandler.post {
                        methodChannel.invokeMethod(
                            "onOneKeyMeasurementStream",
                            mapOf(
                                "hr" to hr,
                                "spo2" to 0,
                                "sbp" to sbp,
                                "dbp" to dbp,
                                "fatigue" to 0,
                                "score" to 0
                            )
                        )
                    }
                },
                false
            )
            result.success(mapOf("started" to true))
        } catch (e: Exception) {
            okmActive = false
            Log.e("HlthBLE", "startOneKeyMeasurement failed", e)
            result.error("OKM_FAILED", e.message, null)
        }
    }

    private fun stopOneKeyMeasurement(result: MethodChannel.Result) {
        if (!okmActive) {
            result.success(mapOf("stopped" to false, "reason" to "not running"))
            return
        }
        okmActive = false
        try {
            Log.i("HlthBLE", "stopOneKeyMeasurement: manualModeBP stop")
            BleOperateManager.getInstance().manualModeBP(
                ICommandResponse<StartHeartRateRsp> { _ -> },
                true
            )
            result.success(mapOf("stopped" to true))
        } catch (e: Exception) {
            Log.e("HlthBLE", "stopOneKeyMeasurement failed", e)
            result.error("OKM_FAILED", e.message, null)
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
     * Sleep sync for a specific past day (0 = today, 1..29 = N nights ago).
     *
     * Uses the SDK's PUBLIC API `BleOperateManager.getSleep(dayIndex,
     * HealthDataCallback<SleepDisplay>)` — the same call the QRing demo's
     * "Specific Day Data" button uses (see QRing_Android_SDK_1.0.0.17/app/
     * .../activity/SleepActivity.kt:39). Earlier attempts used
     * `LargeDataHandler.syncSleepListIndianDemand` (wrong — int arg is a
     * flag, not day offset) and `SleepAnalyzerUtils.theDayBefore` via
     * reflection (wrong — private internal API that hangs without the
     * BleOperateManager wrapper's task scheduling). The public API
     * handles command queuing, timeouts, and error surfacing internally.
     *
     * Stage type codes in SleepDisplay.list[].type: 1=deep, 2=light,
     * 3=wake, 4=rem, 5=no_sleep/no_wear.
     */
    private fun syncSleep(dayOffset: Int, result: MethodChannel.Result) {
        val replied = java.util.concurrent.atomic.AtomicBoolean(false)
        try {
            Log.i("HlthBLE", "syncSleep: dayOffset=$dayOffset (BleOperateManager.getSleep)")
            BleOperateManager.getInstance().getSleep(
                dayOffset,
                object : BleOperateManager.HealthDataCallback<SleepDisplay> {
                    override fun onSuccess(display: SleepDisplay?) {
                        if (!replied.compareAndSet(false, true)) return
                        if (display == null) {
                            Log.i("HlthBLE", "syncSleep: onSuccess(null) — no sleep data for day=$dayOffset")
                            result.success(emptyMap<String, Any>())
                            return
                        }
                        Log.i("HlthBLE", "syncSleep: onSuccess sleepTime=${display.sleepTime}, list size=${display.list?.size ?: 0}")
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

                    override fun onError(code: Int, message: String?) {
                        if (!replied.compareAndSet(false, true)) return
                        Log.w("HlthBLE", "syncSleep: onError code=$code msg=$message")
                        result.error("SYNC_SLEEP_FAILED", message ?: "code=$code", code)
                    }
                }
            )
        } catch (e: Exception) {
            if (replied.compareAndSet(false, true)) {
                Log.e("HlthBLE", "syncSleep dayOffset=$dayOffset failed", e)
                result.error("SYNC_SLEEP_FAILED", e.message, null)
            }
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

    /**
     * Demo-parity step buckets via public API (StepsActivity.kt:38-46).
     *   dayOffset 0  → BleOperateManager.getTodayStepDetail(callback)
     *   dayOffset 1..29 → BleOperateManager.getStepDetail(dayIndex, callback)
     * Returns the same 15-min bin shape as [syncStepsDetail] for shape compat.
     */
    private fun syncStepsDay(dayOffset: Int, result: MethodChannel.Result) {
        val replied = java.util.concurrent.atomic.AtomicBoolean(false)
        val callback = object : BleOperateManager.HealthDataCallback<List<BleStepDetails>> {
            override fun onSuccess(data: List<BleStepDetails>?) {
                if (!replied.compareAndSet(false, true)) return
                val bins = (data ?: emptyList()).map { d ->
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
                Log.i("HlthBLE", "syncStepsDay dayOffset=$dayOffset bins=${bins.size}")
                result.success(bins)
                markSync()
            }

            override fun onError(errorCode: Int, errorMessage: String?) {
                if (!replied.compareAndSet(false, true)) return
                Log.w("HlthBLE", "syncStepsDay err=$errorCode msg=$errorMessage")
                result.error("SYNC_STEPS_DAY_FAILED", "err=$errorCode $errorMessage", null)
            }
        }
        try {
            if (dayOffset == 0) {
                BleOperateManager.getInstance().getTodayStepDetail(callback)
            } else {
                BleOperateManager.getInstance().getStepDetail(dayOffset, callback)
            }
        } catch (e: Exception) {
            if (replied.compareAndSet(false, true)) {
                Log.e("HlthBLE", "syncStepsDay dayOffset=$dayOffset failed", e)
                result.error("SYNC_STEPS_DAY_FAILED", e.message, null)
            }
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
