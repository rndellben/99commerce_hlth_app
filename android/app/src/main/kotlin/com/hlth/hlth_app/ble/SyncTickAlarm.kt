package com.hlth.hlth_app.ble

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Doze-piercing periodic sync tick.
 *
 * The original tick used `Handler.postDelayed`, whose uptime clock FREEZES
 * while the CPU deep-sleeps — verified on-device 2026-07-08 (crumbs): the
 * "30-min" tick fired at 23:48 → 01:00 → 04:56 → 06:00 → 11:40, i.e. 4–6 h
 * gaps across the night. Every overnight feature (nightly BP, sleep-onset
 * detection, PPG capture retries, HRV backfill) starves at that cadence.
 *
 * `AlarmManager.setAndAllowWhileIdle(RTC_WAKEUP …)` is the one scheduling
 * primitive Android guarantees to fire in Doze without the exact-alarm
 * permission (while-idle throttle ≈ 9 min minimum — far below our 30-min
 * cadence). Each fire re-arms the next one (alarm chain).
 *
 * Delivery: [onTick] is set by the live [BleManager] (last-registered engine
 * wins — matches the one-Dart-brain invariant). If the alarm fires in a
 * process with NO engine attached (OS restarted the process, or the app was
 * killed and the sticky service hasn't revived Dart yet), we start the
 * headless engine instead — a bonus revival path alongside the watchdog.
 *
 * The chain deliberately keeps running while the band is DISCONNECTED: the
 * Dart tick handler now owns reconnect-then-sync, so an overnight BLE drop
 * self-heals on the next tick instead of silencing data until morning.
 */
class SyncTickAlarm : BroadcastReceiver() {

    companion object {
        private const val TAG = "HlthTickAlarm"
        private const val REQUEST_CODE = 9101
        private const val DEFAULT_INTERVAL_MS = 30L * 60L * 1000L

        /** Fired on the main thread when the alarm lands. Set by BleManager. */
        @Volatile
        var onTick: (() -> Unit)? = null

        /** Live cadence; BleManager updates it on setSyncIntervalMinutes.
         *  Resets to the 30-min default if the process is reborn — the Dart
         *  side re-applies any custom cadence on its next settings write. */
        @Volatile
        var intervalMs: Long = DEFAULT_INTERVAL_MS

        /** (Re)arm the next tick [intervalMs] from now, replacing any
         *  pending one. Idempotent — safe to call on every connect edge. */
        fun schedule(context: Context) {
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val pi = pendingIntent(context)
            am.cancel(pi)
            am.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                System.currentTimeMillis() + intervalMs,
                pi,
            )
        }

        fun cancel(context: Context) {
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            am.cancel(pendingIntent(context))
        }

        private fun pendingIntent(context: Context): PendingIntent =
            PendingIntent.getBroadcast(
                context,
                REQUEST_CODE,
                Intent(context, SyncTickAlarm::class.java),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
    }

    override fun onReceive(context: Context, intent: Intent) {
        val cb = onTick
        Log.i(TAG, "tick alarm fired (engine=${if (cb != null) "attached" else "none"})")
        if (cb != null) {
            try {
                cb()
            } catch (e: Exception) {
                Log.w(TAG, "tick delivery failed: ${e.message}")
            }
        } else {
            // No Dart brain in this process — revive the headless engine so
            // the tick isn't wasted. Guarded internally against a live UI.
            try {
                HeadlessSyncEngine.start(context.applicationContext)
            } catch (e: Exception) {
                Log.w(TAG, "headless revival from alarm failed: ${e.message}")
            }
        }
        // Always re-arm — the chain is the heartbeat of overnight collection.
        schedule(context.applicationContext)
    }
}
