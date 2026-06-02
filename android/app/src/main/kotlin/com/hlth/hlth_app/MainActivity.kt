package com.hlth.hlth_app

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.hlth.hlth_app.ble.BleManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {

    companion object {
        private const val REQ_POST_NOTIFICATIONS = 1001
    }

    private lateinit var bleManager: BleManager

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Android 13+ requires runtime grant for POST_NOTIFICATIONS, otherwise
        // the foreground service's persistent notification is silently
        // suppressed. The service itself still runs and keeps BLE alive, but
        // the user has no visible indicator that the band is connected.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val granted = ContextCompat.checkSelfPermission(
                this, Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED
            if (!granted) {
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                    REQ_POST_NOTIFICATIONS
                )
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        bleManager = BleManager(applicationContext, this)
        bleManager.register(flutterEngine)
    }
}
