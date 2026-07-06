//
//  BleManager+Background.swift
//  Runner
//
//  Task 10: foreground periodic-sync tick + runtime interval control.
//
//  The foreground `Timer` fires `onPeriodicSyncTick` every
//  `syncIntervalMinutes` while the app is active and the band is connected,
//  mirroring Android's scheduled SyncService trigger. CoreBluetooth state
//  restoration and the BGTaskScheduler-driven background tick (Tasks 12/14)
//  will be added to this same file later.
//

import Foundation
import Flutter

extension BleManager {
    /// Schedule a repeating tick every `syncIntervalMinutes`. Pure Swift —
    /// no SDK involvement; the Dart side reacts by running SyncService.syncAll.
    func startPeriodicTimer() {
        stopPeriodicTimer()
        let interval = TimeInterval(syncIntervalMinutes * 60)
        periodicTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.callDart("onPeriodicSyncTick", ["intervalMin": self.syncIntervalMinutes])
        }
    }

    func stopPeriodicTimer() {
        periodicTimer?.invalidate()
        periodicTimer = nil
    }

    /// Set the periodic-sync cadence at runtime. Clamp to [5, 60] minutes,
    /// reschedule the timer if currently connected, and report the applied
    /// value plus whether the request had to be clamped.
    func setSyncIntervalMinutes(_ a: [String: Any], _ result: @escaping FlutterResult) {
        let requested = a["minutes"] as? Int ?? 30
        let clamped = min(60, max(5, requested))
        syncIntervalMinutes = clamped
        if connectedPeripheral != nil { startPeriodicTimer() }
        result(["minutes": clamped, "clamped": clamped != requested])
    }
}
