package com.hlth.hlth_app.ble

import android.bluetooth.BluetoothDevice
import android.util.Log
import com.oudmon.ble.base.bluetooth.DeviceManager
import com.oudmon.ble.base.bluetooth.QCBluetoothCallbackCloneReceiver
import com.oudmon.ble.base.communication.CommandHandle
import com.oudmon.ble.base.communication.Constants
import com.oudmon.ble.base.communication.LargeDataHandler
import com.oudmon.ble.base.communication.req.SimpleKeyReq

/**
 * Receives BLE state callbacks from the QRing SDK. Mirrors the demo's
 * `MyBluetoothReceiver` — the SDK fires these as broadcast intents and
 * requires a `QCBluetoothCallbackCloneReceiver` registered at the
 * Application level to track its own state correctly.
 *
 * **Without this receiver, the SDK doesn't fully initialize after
 * connection.** `LargeDataHandler.initEnable()` (called on
 * `onServiceDiscovered`) is what activates the notification pipeline,
 * scheduled-data sync paths, and auto-reconnect logic. The connection
 * works without it but drops on the first idle period and the band
 * refuses to re-pair until force-stopped.
 *
 * Connection state changes are also forwarded to Dart so the UI can
 * react to drops in real-time.
 */
class HlthBluetoothReceiver : QCBluetoothCallbackCloneReceiver() {

    companion object {
        /**
         * Process-global "is the band connected right now". The BLE link is
         * owned by the SDK singletons and OUTLIVES any single Flutter engine —
         * a freshly-attached engine (reopen after swipe-away) has missed every
         * onConnected event and would otherwise assume `disconnected` forever.
         * [BleManager]'s `getConnectionState` reads this so a new engine can
         * seed its state from reality instead of showing a phantom disconnect.
         */
        @JvmStatic
        @Volatile
        var isBandConnected: Boolean = false
            internal set
    }

    /** Called by HlthApplication after MethodChannel is registered. */
    var onConnectionChange: ((connected: Boolean, deviceName: String?) -> Unit)? = null

    override fun connectStatue(device: BluetoothDevice?, connected: Boolean) {
        val name = device?.name
        Log.i("HlthBLE", "connectStatue: connected=$connected device=$name")
        isBandConnected = connected
        if (connected && name != null) {
            DeviceManager.getInstance().deviceName = name
        }
        onConnectionChange?.invoke(connected, name)
    }

    override fun onServiceDiscovered() {
        Log.i("HlthBLE", "onServiceDiscovered — calling initEnable() + CMD_BIND_SUCCESS")
        // Critical: this primes the SDK's notification + sync pipelines.
        // Demo calls this on every service discovery; required for
        // connection to stay stable and for sync commands to work.
        LargeDataHandler.getInstance().initEnable()
        // Tell the band the bond is acknowledged. Without this, the band
        // gets confused about its bond state and drops the connection
        // after the first idle period. Demo sends this in BindActivity.
        try {
            CommandHandle.getInstance().executeReqCmdNoCallback(
                SimpleKeyReq(Constants.CMD_BIND_SUCCESS)
            )
        } catch (e: Exception) {
            Log.w("HlthBLE", "CMD_BIND_SUCCESS send failed: ${e.message}")
        }
        isBandConnected = true
        onConnectionChange?.invoke(true, DeviceManager.getInstance().deviceName)
    }

    override fun onCharacteristicChange(address: String?, uuid: String?, data: ByteArray?) {
        // Quiet — fires for every characteristic update. Don't log.
    }

    override fun onCharacteristicRead(uuid: String?, data: ByteArray?) {
        // Firmware / hardware version reads land here. Not needed for v1.
    }
}
