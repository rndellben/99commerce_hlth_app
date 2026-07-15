import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/bootstrap/active_session.dart';
import 'package:hlth_app/core/routing/router.dart';
import 'package:hlth_app/core/services/alerts/alert_evaluator.dart';
import 'package:hlth_app/core/services/app_activity_tracker.dart';
import 'package:hlth_app/core/services/scheduled_ppg_capture_service.dart';
import 'package:hlth_app/core/sync/periodic_sync_coordinator.dart';
import 'package:hlth_app/core/providers/health_data_providers.dart';
import 'package:hlth_app/ui/theme/app_theme.dart';

class HlthApp extends ConsumerStatefulWidget {
  const HlthApp({super.key});

  @override
  ConsumerState<HlthApp> createState() => _HlthAppState();
}

class _HlthAppState extends ConsumerState<HlthApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Launching the app IS user interaction — stamp it so night-time rules
    // (bedtime reminder) have wake evidence from the very first session.
    AppActivityTracker.recordAppActive();
    // Then evaluate alerts against that fresh evidence. Without this, an
    // alert whose evidence is the launch itself (bedtime reminder at 1 a.m.)
    // would wait for the next 30-min sync tick — by which time the evidence
    // may be stale and the moment gone. Post-frame so providers are live;
    // rate limits make re-evaluation cheap and double-fire-safe.
    WidgetsBinding.instance.addPostFrameCallback((_) => _evaluateAlerts());
  }

  void _evaluateAlerts() {
    try {
      ref
          .read(alertEvaluatorProvider)
          .evaluateAll(userId: ActiveSession.defaultUserId);
    } catch (_) {
      // Alert evaluation must never break app startup/resume.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The home/metric providers below capture the wall-clock date (today,
    // last-24h cutoff) ONCE when they're first built and never refresh it.
    // If the app stays alive across a day boundary — e.g. left running
    // overnight — they keep watching the previous day, so today's freshly
    // written daily_metrics (scheduled overnight captures, manual analyses)
    // are invisible. Invalidating them on resume re-evaluates DateTime.now()
    // so "today" is current again whenever the user returns to the app.
    if (state == AppLifecycleState.resumed) {
      // Foregrounding the app is irrefutable "user is awake" evidence for
      // the bedtime reminder (a sleeping person cannot resume an app) — and
      // the evaluation runs NOW, not on the next tick, so the reminder can
      // fire while the evidence is seconds old.
      AppActivityTracker.recordAppActive();
      _evaluateAlerts();
      ref.invalidate(todayDailyMetricsProvider);
      ref.invalidate(hrSparklineProvider);
      ref.invalidate(spo2SparklineProvider);
      ref.invalidate(hrvSparklineProvider);
      ref.invalidate(bpSparklineProvider);
      ref.invalidate(stressSparklineProvider);
      // Respiratory has no band-native source — it needs an active PPG
      // capture. Kick one on resume so simply re-opening the app refreshes
      // the card. Fully self-gated (skips if already captured today / a
      // capture is in flight / not connected / daily attempt cap reached),
      // so this can't double-capture or run when it shouldn't.
      ref
          .read(scheduledPpgCaptureServiceProvider)
          .maybeRunDaily(userId: ActiveSession.defaultUserId);
    }
  }

  @override
  Widget build(BuildContext context) {
    // HLT-11: read the coordinator once so its tick-stream subscription
    // gets wired at app boot. Riverpod providers are lazy — without this
    // touch, the coordinator wouldn't instantiate until something else
    // happened to read it.
    ref.watch(periodicSyncCoordinatorProvider);
    return MaterialApp.router(
      title: 'HLTH',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
