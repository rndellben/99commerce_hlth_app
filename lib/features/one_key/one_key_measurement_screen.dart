import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/ble/ble_service.dart';
import 'package:hlth_app/ui/theme/app_colors.dart';

/// One Key Measurement — chains three band-side manual measurements per
/// SDK PDF §2.3.7:
///
///   Phase 1 (HR,   ~20s) — manualModeHeart → bpm
///   Phase 2 (SpO2, ~25s) — manualModeSpO2  → %
///   Phase 3 (BP,   ~30s) — manualModeBP    → sbp/dbp
///
/// We have to chain because the SDK's documented `startOneKey` API
/// crashes inside the SDK on H59 firmware (ClassCastException between
/// StopHeartRateRsp and StartHeartRateRsp on notify 0x69). Chaining the
/// per-metric manual modes is the documented alternative and works on
/// every firmware build we've tested.
class OneKeyMeasurementScreen extends ConsumerStatefulWidget {
  const OneKeyMeasurementScreen({super.key});

  @override
  ConsumerState<OneKeyMeasurementScreen> createState() =>
      _OneKeyMeasurementScreenState();
}

enum _Phase { idle, hr, spo2, bp, done }

class _OneKeyMeasurementScreenState
    extends ConsumerState<OneKeyMeasurementScreen> {
  // Safety caps per phase. Observed convergence times on H59 fw
  // (BLE debug screen, 2026-06-11):
  //   • Start BP   → result 102/71 in 35s
  //   • Start SpO2 → 97% in 41s
  // The caps below are generous floors; converge-early fires the moment
  // a real value lands so a healthy measurement typically finishes in
  // 30-45s per phase. If you bump these, also bump the band-side timeout
  // hint in [BleManager.kt] manualMode* docs.
  static const _hrDuration = Duration(seconds: 60);
  static const _spo2Duration = Duration(seconds: 60);
  static const _bpDuration = Duration(seconds: 60);
  // Small gap between phases so the band's PPG can switch LED
  // wavelengths (green→red+IR→pulse-timing) cleanly. Without this,
  // back-to-back manualMode* calls sometimes never converge.
  static const _phaseGap = Duration(milliseconds: 1500);

  _Phase _phase = _Phase.idle;
  int? _hr;
  int? _spo2;
  int? _sbp;
  int? _dbp;
  int _secondsRemaining = 0;
  String? _error;

  Timer? _phaseTimer;
  Timer? _countdownTimer;
  StreamSubscription? _hrSub;
  StreamSubscription? _spo2Sub;
  StreamSubscription? _okmSub;

  @override
  void dispose() {
    _cancelTimers();
    _cancelSubs();
    if (_phase != _Phase.idle && _phase != _Phase.done) {
      _abortBandSide();
    }
    super.dispose();
  }

  void _cancelTimers() {
    _phaseTimer?.cancel();
    _countdownTimer?.cancel();
    _phaseTimer = null;
    _countdownTimer = null;
  }

  void _cancelSubs() {
    _hrSub?.cancel();
    _spo2Sub?.cancel();
    _okmSub?.cancel();
    _hrSub = null;
    _spo2Sub = null;
    _okmSub = null;
  }

  Future<void> _abortBandSide() async {
    final ble = ref.read(bleServiceProvider);
    try {
      await ble.stopHeartStream();
    } catch (_) {}
    try {
      await ble.stopSpo2Stream();
    } catch (_) {}
    try {
      await ble.stopOneKeyMeasurement();
    } catch (_) {}
  }

  Future<void> _start() async {
    setState(() {
      _hr = null;
      _spo2 = null;
      _sbp = null;
      _dbp = null;
      _error = null;
    });
    await _runPhaseHr();
  }

  Future<void> _stop() async {
    _cancelTimers();
    _cancelSubs();
    await _abortBandSide();
    if (!mounted) return;
    setState(() {
      _phase = _Phase.idle;
      _secondsRemaining = 0;
    });
  }

  Future<void> _runPhaseHr() async {
    final ble = ref.read(bleServiceProvider);
    setState(() {
      _phase = _Phase.hr;
      _secondsRemaining = _hrDuration.inSeconds;
    });
    _hrSub = ble.hrActiveStream.listen((hr) {
      if (!mounted || hr <= 0) return;
      setState(() => _hr = hr);
      // Converge-early: as soon as the band gives us a real bpm, move
      // to the SpO2 phase instead of burning the full window.
      _phaseTimer?.cancel();
      _phaseTimer = null;
      Future(() async {
        try {
          await ble.stopHeartStream();
        } catch (_) {}
        _hrSub?.cancel();
        _hrSub = null;
        await Future.delayed(_phaseGap);
        if (mounted) _runPhaseSpo2();
      });
    });
    try {
      await ble.startHeartStream();
    } catch (e) {
      _failWith('HR measurement failed: $e');
      return;
    }
    _startCountdown();
    _phaseTimer = Timer(_hrDuration, () async {
      try {
        await ble.stopHeartStream();
      } catch (_) {}
      _hrSub?.cancel();
      _hrSub = null;
      await Future.delayed(_phaseGap);
      if (mounted) _runPhaseSpo2();
    });
  }

  Future<void> _runPhaseSpo2() async {
    _cancelTimers();
    final ble = ref.read(bleServiceProvider);
    setState(() {
      _phase = _Phase.spo2;
      _secondsRemaining = _spo2Duration.inSeconds;
    });
    _spo2Sub = ble.spo2Stream.listen((t) {
      if (!mounted || t.spo2 <= 0) return;
      setState(() {
        _spo2 = t.spo2;
        if (t.hr > 0 && _hr == null) _hr = t.hr;
      });
      // Converge-early — same rationale as the HR phase.
      _phaseTimer?.cancel();
      _phaseTimer = null;
      Future(() async {
        try {
          await ble.stopSpo2Stream();
        } catch (_) {}
        _spo2Sub?.cancel();
        _spo2Sub = null;
        await Future.delayed(_phaseGap);
        if (mounted) _runPhaseBp();
      });
    });
    try {
      await ble.startSpo2Stream();
    } catch (e) {
      _failWith('SpO2 measurement failed: $e');
      return;
    }
    _startCountdown();
    _phaseTimer = Timer(_spo2Duration, () async {
      try {
        await ble.stopSpo2Stream();
      } catch (_) {}
      _spo2Sub?.cancel();
      _spo2Sub = null;
      await Future.delayed(_phaseGap);
      if (mounted) _runPhaseBp();
    });
  }

  Future<void> _runPhaseBp() async {
    _cancelTimers();
    final ble = ref.read(bleServiceProvider);
    setState(() {
      _phase = _Phase.bp;
      _secondsRemaining = _bpDuration.inSeconds;
    });
    _okmSub = ble.oneKeyMeasurementStream.listen((t) {
      if (!mounted) return;
      setState(() {
        if (t.sbp > 0) _sbp = t.sbp;
        if (t.dbp > 0) _dbp = t.dbp;
        if (t.hr > 0 && _hr == null) _hr = t.hr;
      });
      // Converge-early: H59 fw fires the first non-zero sbp/dbp once,
      // right at the end of its ~30s measurement window. Don't wait the
      // full timeout — finish as soon as the converged pair lands.
      if (t.sbp > 0 && t.dbp > 0) {
        _phaseTimer?.cancel();
        _phaseTimer = null;
        Future(() async {
          try {
            await ble.stopOneKeyMeasurement();
          } catch (_) {}
          _okmSub?.cancel();
          _okmSub = null;
          if (mounted) _finish();
        });
      }
    });
    try {
      await ble.startOneKeyMeasurement();
    } catch (e) {
      _failWith('BP measurement failed: $e');
      return;
    }
    _startCountdown();
    _phaseTimer = Timer(_bpDuration, () async {
      try {
        await ble.stopOneKeyMeasurement();
      } catch (_) {}
      _okmSub?.cancel();
      _okmSub = null;
      if (mounted) _finish();
    });
  }

  void _finish() {
    _cancelTimers();
    if (!mounted) return;
    setState(() {
      _phase = _Phase.done;
      _secondsRemaining = 0;
    });
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _secondsRemaining--);
      if (_secondsRemaining <= 0) {
        _countdownTimer?.cancel();
        _countdownTimer = null;
      }
    });
  }

  void _failWith(String msg) {
    _cancelTimers();
    _cancelSubs();
    if (!mounted) return;
    setState(() {
      _phase = _Phase.idle;
      _error = msg;
    });
  }

  String get _statusLine {
    switch (_phase) {
      case _Phase.idle:
        return 'Tap "Start Measurement" to begin';
      case _Phase.hr:
        return 'Measuring Heart Rate — ${_secondsRemaining}s';
      case _Phase.spo2:
        return 'Measuring Blood Oxygen — ${_secondsRemaining}s';
      case _Phase.bp:
        return 'Measuring Blood Pressure — ${_secondsRemaining}s';
      case _Phase.done:
        return 'Measurement complete';
    }
  }

  bool get _running =>
      _phase == _Phase.hr || _phase == _Phase.spo2 || _phase == _Phase.bp;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('One Key Measurement')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _StatusCard(
                statusLine: _statusLine,
                running: _running,
                phase: _phase,
              ),
              const SizedBox(height: 20),
              _ResultCard(hr: _hr, spo2: _spo2, sbp: _sbp, dbp: _dbp),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: _running ? _stop : _start,
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        _running ? AppColors.error : AppColors.activity,
                  ),
                  child: Text(
                    _running ? 'Stop Measurement' : 'Start Measurement',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Note: This measurement is for reference only and cannot '
                'replace medical diagnosis.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.statusLine,
    required this.running,
    required this.phase,
  });
  final String statusLine;
  final bool running;
  final _Phase phase;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: running
              ? AppColors.activity.withValues(alpha: 0.5)
              : AppColors.divider,
        ),
      ),
      child: Column(
        children: [
          Text(
            statusLine,
            style: TextStyle(
              fontSize: 14,
              color: running ? AppColors.activity : AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.activity.withValues(alpha: 0.4),
                width: 2,
              ),
            ),
            child: Center(
              child: Icon(
                Icons.accessibility_new,
                size: 80,
                color: AppColors.activity.withValues(
                  alpha: running ? 0.9 : 0.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _PhaseDots(phase: phase),
        ],
      ),
    );
  }
}

class _PhaseDots extends StatelessWidget {
  const _PhaseDots({required this.phase});
  final _Phase phase;

  bool _isDone(_Phase p) {
    if (phase == _Phase.done) return true;
    final order = [_Phase.hr, _Phase.spo2, _Phase.bp];
    return order.indexOf(p) < order.indexOf(phase);
  }

  bool _isActive(_Phase p) => phase == p;

  Widget _dot(String label, _Phase p) {
    final done = _isDone(p);
    final active = _isActive(p);
    final color = done || active ? AppColors.activity : AppColors.textTertiary;
    return Column(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: done || active ? color : color.withValues(alpha: 0.3),
            shape: BoxShape.circle,
            border: Border.all(color: color),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: active ? AppColors.activity : AppColors.textTertiary,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _dot('HR', _Phase.hr),
        _dot('SpO2', _Phase.spo2),
        _dot('BP', _Phase.bp),
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({this.hr, this.spo2, this.sbp, this.dbp});
  final int? hr;
  final int? spo2;
  final int? sbp;
  final int? dbp;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          _row(
            label: 'Heart Rate',
            unit: 'bpm',
            value: hr?.toString() ?? '--',
            color: AppColors.heartRate,
          ),
          const SizedBox(height: 14),
          _row(
            label: 'Blood Oxygen',
            unit: '%',
            value: spo2?.toString() ?? '--',
            color: AppColors.spo2,
          ),
          const SizedBox(height: 14),
          _row(
            label: 'Blood Pressure',
            unit: 'mmHg',
            value: (sbp != null && dbp != null) ? '$sbp/$dbp' : '--',
            color: AppColors.bloodPressure,
          ),
        ],
      ),
    );
  }

  Widget _row({
    required String label,
    required String unit,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text('$label  ', style: const TextStyle(fontSize: 14)),
        ),
        Text(
          unit,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
