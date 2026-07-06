package com.hlth.hlth_app

import android.app.Application
import android.util.Log
import androidx.core.content.ContextCompat
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import com.hlth.hlth_app.ble.HlthBluetoothReceiver
import com.oudmon.ble.base.bluetooth.BleAction
import com.oudmon.ble.base.bluetooth.BleOperateManager
import java.util.concurrent.TimeUnit

/**
 * App-wide initialization for the QRing BLE SDK. Without this, calling
 * `BleOperateManager.getInstance()` from any other class crashes with a
 * null-application-context NullPointerException.
 *
 * Mirrors the init done in the QRing demo's `MyApplication.kt`.
 *
 * Critical: also registers the `HlthBluetoothReceiver` so the SDK can
 * call back into the app for connect/disconnect/service-discovered events.
 * Without this receiver, the SDK doesn't fully initialize after each
 * connection and the band drops on the first idle period.
 */
class HlthApplication : Application() {

    companion object {
        @JvmStatic
        lateinit var bluetoothReceiver: HlthBluetoothReceiver
            private set
    }

    override fun onCreate() {
        super.onCreate()

        // One-shot cleanup of the pre-drift sqflite database. Old dev
        // builds wrote to <appData>/databases/hlth_app.db; the canonical
        // drift store now lives in app-support as hlth_app.sqlite. If
        // the legacy file is still on disk it's orphaned dead weight —
        // delete it. Idempotent: no-op if already gone.
        deleteLegacySqfliteDb()

        // Two-step SDK init.
        BleOperateManager.getInstance(this)
        BleOperateManager.getInstance().init()

        // Register the BLE state receiver at app scope so it survives
        // activity recreation and navigation.
        bluetoothReceiver = HlthBluetoothReceiver()
        ContextCompat.registerReceiver(
            applicationContext,
            bluetoothReceiver,
            BleAction.getIntentFilter(),
            ContextCompat.RECEIVER_NOT_EXPORTED
        )

        // Background-sync watchdog: every ~15 min WorkManager wakes the
        // process and SyncWatchdogWorker revives the headless sync engine if
        // no Dart brain is alive (killed by an OEM reaper, or after a
        // reboot — WorkManager's schedule persists across restarts, so this
        // doubles as the boot-recovery path). KEEP: never reset an existing
        // schedule on app start.
        try {
            WorkManager.getInstance(this).enqueueUniquePeriodicWork(
                SyncWatchdogWorker.UNIQUE_NAME,
                ExistingPeriodicWorkPolicy.KEEP,
                PeriodicWorkRequestBuilder<SyncWatchdogWorker>(
                    15, TimeUnit.MINUTES
                ).build()
            )
        } catch (e: Exception) {
            Log.w("HlthApp", "watchdog scheduling failed: ${e.message}")
        }
    }

    private fun deleteLegacySqfliteDb() {
        // sqflite stored files under getDatabasePath(name). We also clean
        // up the WAL and journal sidecars that may have been left behind.
        for (name in listOf("hlth_app.db", "hlth_app.db-journal", "hlth_app.db-wal", "hlth_app.db-shm")) {
            try {
                val file = getDatabasePath(name)
                if (file != null && file.exists() && file.delete()) {
                    Log.i("HlthApp", "deleted legacy sqflite file: ${file.absolutePath}")
                }
            } catch (e: Exception) {
                Log.w("HlthApp", "legacy db cleanup failed for $name: ${e.message}")
            }
        }
    }
}
