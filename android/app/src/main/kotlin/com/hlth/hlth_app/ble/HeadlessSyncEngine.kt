package com.hlth.hlth_app.ble

import android.content.Context
import android.util.Log
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor

/**
 * Holder for the background ("headless") Flutter engine that keeps sync +
 * scoring + alerts running after the user swipes the app away.
 *
 * The BLE architecture splits the brain in two: Kotlin owns the connection,
 * but ALL orchestration (syncAll, scores, alert evaluation, the morning
 * push) lives in Dart. The UI engine dies with the task, so without this,
 * swiping the app away silences data collection until the next manual open.
 *
 * Lifecycle:
 *  * `start()` — spins up a [FlutterEngine] executing the `backgroundMain`
 *    entrypoint (lib/background_main.dart) and registers a [BleManager] on
 *    it (activity = null: scanning is unavailable headless, but direct
 *    connect-by-MAC — all we need — works). Idempotent.
 *  * `stop()` — destroys the engine. Called by [com.hlth.hlth_app.MainActivity]
 *    BEFORE it registers the UI engine, so exactly ONE Dart sync brain is
 *    alive at a time (two would double-run syncAll and contend on SQLite).
 *
 * Callers: [BleForegroundService.onTaskRemoved] (swipe-away),
 * [BleForegroundService.onStartCommand] with a null intent (STICKY restart
 * after process death), and [com.hlth.hlth_app.SyncWatchdogWorker] (15-min
 * WorkManager revive after OEM kills / reboot).
 */
object HeadlessSyncEngine {

    private const val TAG = "HlthHeadless"
    private const val ENTRYPOINT_LIBRARY = "package:hlth_app/background_main.dart"
    private const val ENTRYPOINT_FUNCTION = "backgroundMain"

    @Volatile
    private var engine: FlutterEngine? = null

    // Kept so the manager (and its SDK listeners) lives exactly as long as
    // the engine it serves.
    @Volatile
    private var bleManager: BleManager? = null

    val isRunning: Boolean get() = engine != null

    @Synchronized
    fun start(context: Context) {
        if (com.hlth.hlth_app.MainActivity.uiEngineAlive) {
            Log.i(TAG, "start: UI engine alive — it owns sync, skipping")
            return
        }
        if (engine != null) {
            Log.i(TAG, "start: already running")
            return
        }
        try {
            val appContext = context.applicationContext
            // In a service-only process (post swipe-away restart) the Flutter
            // loader has never run — the Application class is not a
            // FlutterApplication, so initialize it explicitly.
            val loader = FlutterInjector.instance().flutterLoader()
            if (!loader.initialized()) {
                loader.startInitialization(appContext)
                loader.ensureInitializationComplete(appContext, null)
            }
            val e = FlutterEngine(appContext)
            // BleManager BEFORE the entrypoint executes, so the hlth/ble
            // channel exists by the time backgroundMain's first call lands.
            val manager = BleManager(appContext, null)
            manager.register(e)
            e.dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint(
                    loader.findAppBundlePath(),
                    ENTRYPOINT_LIBRARY,
                    ENTRYPOINT_FUNCTION,
                ),
            )
            engine = e
            bleManager = manager
            Log.i(TAG, "headless sync engine started")
        } catch (t: Throwable) {
            Log.e(TAG, "failed to start headless engine", t)
            engine = null
            bleManager = null
        }
    }

    @Synchronized
    fun stop() {
        val e = engine ?: return
        try {
            e.destroy()
            Log.i(TAG, "headless sync engine stopped")
        } catch (t: Throwable) {
            Log.w(TAG, "engine destroy failed: ${t.message}")
        } finally {
            engine = null
            bleManager = null
        }
    }
}
