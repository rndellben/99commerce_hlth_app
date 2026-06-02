package com.hlth.hlth_app.ble

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat
import com.hlth.hlth_app.MainActivity

/**
 * Foreground service that keeps the BLE connection alive while the band is
 * connected. Started by BleManager on connect, stopped on disconnect.
 *
 * Required so Android doesn't kill the process while we collect overnight
 * PPG, sleep, and HRV data. Without a foreground service the OS will reap
 * the app within minutes of screen-off and the band drops.
 *
 * Lifecycle: BleManager calls `start(context, deviceName)` once on connect.
 * Each successful sync calls `updateLastSync(context, deviceName, nowMs)` to
 * refresh the notification text. On disconnect, BleManager calls
 * `stop(context)`.
 *
 * Android 14+ note: `foregroundServiceType` must be passed to
 * `startForeground` AND declared in the manifest. We use
 * `FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE` (matches the manifest's
 * `android:foregroundServiceType="connectedDevice"`).
 */
class BleForegroundService : Service() {

    companion object {
        private const val TAG = "HlthBleFgService"
        private const val CHANNEL_ID = "hlth_ble_service"
        private const val NOTIFICATION_ID = 9001

        const val ACTION_START = "com.hlth.hlth_app.ble.START"
        const val ACTION_UPDATE = "com.hlth.hlth_app.ble.UPDATE"
        const val ACTION_STOP = "com.hlth.hlth_app.ble.STOP"
        const val EXTRA_DEVICE_NAME = "device_name"
        const val EXTRA_LAST_SYNC_MS = "last_sync_ms"

        fun start(context: Context, deviceName: String?) {
            val intent = Intent(context, BleForegroundService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_DEVICE_NAME, deviceName ?: "")
            }
            ContextCompat.startForegroundService(context, intent)
        }

        fun updateLastSync(context: Context, deviceName: String?, lastSyncMs: Long) {
            val intent = Intent(context, BleForegroundService::class.java).apply {
                action = ACTION_UPDATE
                putExtra(EXTRA_DEVICE_NAME, deviceName ?: "")
                putExtra(EXTRA_LAST_SYNC_MS, lastSyncMs)
            }
            ContextCompat.startForegroundService(context, intent)
        }

        fun stop(context: Context) {
            val intent = Intent(context, BleForegroundService::class.java).apply {
                action = ACTION_STOP
            }
            context.startService(intent)
        }
    }

    private var deviceName: String = ""
    private var lastSyncMs: Long = 0L

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                Log.i(TAG, "stop requested")
                ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_UPDATE -> {
                intent.getStringExtra(EXTRA_DEVICE_NAME)?.takeIf { it.isNotEmpty() }
                    ?.let { deviceName = it }
                val ts = intent.getLongExtra(EXTRA_LAST_SYNC_MS, 0L)
                if (ts > 0) lastSyncMs = ts
                // Always promote first — startForeground is idempotent and
                // protects against ForegroundServiceDidNotStartInTimeException
                // if ACTION_UPDATE ever races ahead of ACTION_START.
                promoteToForeground()
                return START_STICKY
            }
            else -> {
                // ACTION_START or null (system restart)
                intent?.getStringExtra(EXTRA_DEVICE_NAME)?.takeIf { it.isNotEmpty() }
                    ?.let { deviceName = it }
                promoteToForeground()
                return START_STICKY
            }
        }
    }

    private fun promoteToForeground() {
        ensureChannel()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ServiceCompat.startForeground(
                this,
                NOTIFICATION_ID,
                buildNotification(),
                ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE
            )
        } else {
            startForeground(NOTIFICATION_ID, buildNotification())
        }
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val mgr = getSystemService(NotificationManager::class.java) ?: return
        if (mgr.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "HLTH band connection",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Keeps the band connection alive in the background"
            setShowBadge(false)
        }
        mgr.createNotificationChannel(channel)
    }

    private fun buildNotification(): Notification {
        val launch = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pi = PendingIntent.getActivity(
            this, 0, launch,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val title = if (deviceName.isNotEmpty()) "HLTH — $deviceName" else "HLTH"
        val body = if (lastSyncMs > 0) {
            "Last synced ${formatAgo(System.currentTimeMillis() - lastSyncMs)}"
        } else {
            "Connected, waiting for first sync"
        }

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(body)
            .setSmallIcon(android.R.drawable.stat_sys_data_bluetooth)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setContentIntent(pi)
            .setShowWhen(false)
            .build()
    }

    private fun formatAgo(deltaMs: Long): String {
        val sec = deltaMs / 1000
        return when {
            sec < 60 -> "just now"
            sec < 3600 -> "${sec / 60}m ago"
            sec < 86400 -> "${sec / 3600}h ago"
            else -> "${sec / 86400}d ago"
        }
    }
}
