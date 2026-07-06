package com.hlth.hlth_app

import android.content.Context
import android.util.Log
import androidx.work.Worker
import androidx.work.WorkerParameters
import com.hlth.hlth_app.ble.HeadlessSyncEngine

/**
 * 15-minute WorkManager watchdog that revives background sync after the OS
 * (or an aggressive OEM like MIUI) kills the process, and after reboots —
 * WorkManager persists its schedule across restarts, so no boot receiver is
 * needed.
 *
 * It does exactly one cheap thing: ensure a Dart sync brain exists.
 *  * UI engine alive → nothing to do (it owns sync).
 *  * Headless engine alive → nothing to do.
 *  * No band ever paired (`flutter.has_bonded_band` pref, written by the
 *    Dart PeriodicSyncCoordinator) → nothing to do — don't burn memory on
 *    an engine that has no device to talk to.
 *  * Otherwise → start the headless engine; its `backgroundMain` reconnects
 *    to the bonded band and the normal tick/sync/alert pipeline resumes.
 */
class SyncWatchdogWorker(
    context: Context,
    params: WorkerParameters,
) : Worker(context, params) {

    companion object {
        private const val TAG = "HlthWatchdog"
        const val UNIQUE_NAME = "hlth-sync-watchdog"
        private const val FLUTTER_PREFS = "FlutterSharedPreferences"
        private const val HAS_BAND_KEY = "flutter.has_bonded_band"
    }

    override fun doWork(): Result {
        if (MainActivity.uiEngineAlive) {
            Log.i(TAG, "UI engine alive — nothing to do")
            return Result.success()
        }
        if (HeadlessSyncEngine.isRunning) {
            Log.i(TAG, "headless engine already running")
            return Result.success()
        }
        val hasBand = applicationContext
            .getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
            .getBoolean(HAS_BAND_KEY, false)
        if (!hasBand) {
            Log.i(TAG, "no bonded band — skipping")
            return Result.success()
        }
        Log.i(TAG, "no sync brain alive — starting headless engine")
        HeadlessSyncEngine.start(applicationContext)
        return Result.success()
    }
}
